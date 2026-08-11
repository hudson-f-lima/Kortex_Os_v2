const workers = [
  { id: 'audit', write_set: [], worktree: 'isolated-a' },
  { id: 'context', write_set: [], worktree: 'isolated-b' }
];
const sets = workers.flatMap(worker => worker.write_set.map(file => [worker.id, file]));
const files = sets.map(([, file]) => file);
const disjoint = new Set(files).size === files.length;
const report = { max_workers: 2, workers: workers.length, isolated_worktrees: workers.every(worker => worker.worktree), write_sets_disjoint: disjoint, status: workers.length <= 2 && disjoint ? 'GO' : 'NO-GO' };
console.log(JSON.stringify(report, null, 2));
if (report.status !== 'GO') process.exit(1);
