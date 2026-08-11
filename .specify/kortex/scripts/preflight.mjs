import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const args = new Map();
for (let i = 2; i < process.argv.length; i += 2) args.set(process.argv[i], process.argv[i + 1]);
const repo = path.resolve(args.get('--repo') || process.env.KORTEX_REPO || process.cwd());
const authorizedInput = args.get('--authorized-root') || process.env.KORTEXOS_AUTHORIZED_ROOT;
const authorized = authorizedInput ? path.resolve(authorizedInput) : null;
const mode = args.get('--mode') || 'read-only-dry-run';
const taskClass = args.get('--task-class') || 'read-only';
const expectedCli = '0.12.11';
const required = [
  'AGENTS.md',
  'docs/INDEX.md',
  'docs/waves/KORTEXOS_5_1_2_TRUTH_MAP.md',
  'docs/waves/KORTEXOS_5_1_2_MIGRATION_MAP.md',
  'docs/architecture/governance/KORTEXOS_DOCUMENTATION_AUTOMATION_PROTOCOL.md'
];

function git(...gitArgs) {
  return execFileSync('git', ['-C', repo, ...gitArgs], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
}
function fail(message) {
  console.error(JSON.stringify({ status: 'BLOCKED', reason: message }));
  process.exit(2);
}

if (!authorized) fail('KORTEXOS_AUTHORIZED_ROOT is required');
if (repo !== authorized) fail('repo root does not match KORTEXOS_AUTHORIZED_ROOT');
if (!fs.existsSync(path.join(repo, '.git'))) fail('repo root is not a Git worktree');
for (const relative of required) if (!fs.existsSync(path.join(repo, relative))) fail(`missing canonical source: ${relative}`);

const branch = git('branch', '--show-current');
const commit = git('rev-parse', 'HEAD');
const upstreamRef = (() => { try { return git('rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{upstream}'); } catch { return null; } })();
const upstream = upstreamRef ? (() => { try { return git('rev-parse', upstreamRef); } catch { return null; } })() : null;
const status = git('status', '--short', '--branch');
const protectedBranch = branch === 'main' || branch === 'staging';
if (protectedBranch && taskClass !== 'read-only' && mode !== 'read-only-dry-run') fail(`protected branch: ${branch}`);
if (taskClass === 'promotion') fail('promotion is never authorized by this local preflight');
if (taskClass !== 'read-only' && !upstream) fail(`no origin tracking ref for branch: ${branch}`);

const sourceHashes = Object.fromEntries(required.map(relative => {
  const content = fs.readFileSync(path.join(repo, relative));
  return [relative, crypto.createHash('sha256').update(content).digest('hex')];
}));

console.log(JSON.stringify({
  status: 'GO',
  read_only: true,
  repository: repo,
  branch,
  commit,
  upstream_ref: upstreamRef,
  upstream,
  clean: status.split('\n').length === 1,
  task_class: taskClass,
  mode,
  cli_version_required: expectedCli,
  canonical_source_hashes: sourceHashes,
  forbidden: ['product code', 'migrations', 'external writes', 'promotion', 'secrets/PII/raw tool output']
}, null, 2));
