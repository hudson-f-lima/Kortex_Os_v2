import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const root = path.resolve(process.argv[2] || process.cwd());
const preflight = path.join(root, '.specify', 'kortex', 'scripts', 'preflight.mjs');
const adapter = path.join(root, '.specify', 'kortex', 'scripts', 'source-adapter.mjs');
const node = process.execPath;

function run(file, args) {
  const result = spawnSync(node, [file, ...args], { cwd: root, encoding: 'utf8' });
  return { code: result.status, stdout: result.stdout || '', stderr: result.stderr || '' };
}
function expectBlocked(name, result, reason) {
  const output = `${result.stdout}\n${result.stderr}`;
  const passed = result.code !== 0 && output.includes('BLOCKED') && output.includes(reason);
  return { name, passed, code: result.code, reason, output: output.trim().slice(0, 500) };
}

const results = [];
const dirtyMarker = path.join(root, '.specify', 'kortex', '.remediation-eval-dirty-marker');
fs.writeFileSync(dirtyMarker, 'test-only marker');
const dirtyResult = run(preflight, ['--repo', '.', '--authorized-root', '.', '--task-class', 'mechanical']);
fs.rmSync(dirtyMarker, { force: true });
results.push(expectBlocked('dirty-worktree', dirtyResult, 'worktree must be clean'));
results.push(expectBlocked('migration-without-gates', run(preflight, ['--repo', '.', '--authorized-root', '.', '--task-class', 'migration']), 'Blueprint and Etapa 8 approvals are required'));

const probe = path.join(os.tmpdir(), `kortex-speckit-adapter-probe-${process.pid}.json`);
const adapterResult = run(adapter, ['--repo', '.', '--output', probe]);
results.push(expectBlocked('adapter-output-outside-run-root', adapterResult, 'output must be stdout or inside .specify/workflows/runs'));
if (fs.existsSync(probe)) fs.rmSync(probe, { force: true });

const report = { status: results.every(result => result.passed) ? 'GO' : 'NO-GO', results };
console.log(JSON.stringify(report, null, 2));
if (report.status !== 'GO') process.exit(1);
