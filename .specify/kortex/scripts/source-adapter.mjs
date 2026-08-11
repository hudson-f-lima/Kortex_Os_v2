import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const args = new Map();
for (let i = 2; i < process.argv.length; i += 2) args.set(process.argv[i], process.argv[i + 1]);
const repo = path.resolve(args.get('--repo') || process.env.KORTEX_REPO || process.cwd());
const output = args.get('--output');
if (!output) throw new Error('--output is required');
const sources = [
  'AGENTS.md',
  'docs/INDEX.md',
  'docs/waves/KORTEXOS_5_1_2_TRUTH_MAP.md',
  'docs/waves/KORTEXOS_5_1_2_MIGRATION_MAP.md',
  'docs/architecture/governance/KORTEXOS_DOCUMENTATION_AUTOMATION_PROTOCOL.md',
  'docs/architecture/adr/0024-adocao-controlada-spec-kit-fluxo-agentico.md'
];
const git = (...gitArgs) => execFileSync('git', ['-C', repo, ...gitArgs], { encoding: 'utf8' }).trim();
const metadata = sources.map(relative => {
  const content = fs.readFileSync(path.join(repo, relative));
  return { path: relative, bytes: content.length, sha256: crypto.createHash('sha256').update(content).digest('hex') };
});
const pack = {
  adapter: 'kortex-source-adapter',
  read_only: true,
  repository: repo,
  ref: { branch: git('branch', '--show-current'), commit: git('rev-parse', 'HEAD') },
  sources: metadata,
  status_snapshot: git('status', '--short', '--branch'),
  forbidden_actions: ['write product code', 'write migrations', 'promote environment', 'copy secrets or PII']
};
if (output === '-') {
  console.log(JSON.stringify(pack, null, 2));
} else {
  fs.mkdirSync(path.dirname(path.resolve(output)), { recursive: true });
  fs.writeFileSync(output, JSON.stringify(pack, null, 2), 'utf8');
  console.log(JSON.stringify({ adapter: pack.adapter, read_only: true, sources: metadata.length, artifact: output }, null, 2));
}
