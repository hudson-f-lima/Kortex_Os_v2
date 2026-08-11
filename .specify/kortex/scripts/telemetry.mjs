import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.argv[2] || '.specify/workflows/runs');
const runDirs = fs.existsSync(root) ? fs.readdirSync(root, { withFileTypes: true }).filter(entry => entry.isDirectory()) : [];
const runs = runDirs.map(entry => {
  const runRoot = path.join(root, entry.name);
  const statePath = path.join(runRoot, 'state.json');
  const state = fs.existsSync(statePath) ? JSON.parse(fs.readFileSync(statePath, 'utf8')) : { status: 'orphaned' };
  const logPath = path.join(runRoot, 'log.jsonl');
  const events = fs.existsSync(logPath) ? fs.readFileSync(logPath, 'utf8').trim().split('\n').filter(Boolean).map(line => JSON.parse(line)) : [];
  return { run_id: entry.name, status: state.status, workflow_id: state.workflow_id || null, events: events.length, orphaned: !fs.existsSync(statePath) };
});
const report = { cli_version: '0.12.11', runs, total_runs: runs.length, completed_runs: runs.filter(run => run.status === 'completed').length, paused_runs: runs.filter(run => run.status === 'paused').length, failed_runs: runs.filter(run => run.status === 'failed').length, orphaned_runs: runs.filter(run => run.orphaned).map(run => run.run_id), tokens_or_cost: 'UNKNOWN' };
console.log(JSON.stringify(report, null, 2));
