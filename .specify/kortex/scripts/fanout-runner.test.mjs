import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { runPlan } from './fanout-runner.mjs';

async function fixtureRepo() {
  const repo = await fs.mkdtemp(path.join(os.tmpdir(), 'kortex-runner-'));
  await fs.mkdir(path.join(repo, '.specify', 'kortex', 'scripts'), { recursive: true });
  await fs.writeFile(path.join(repo, '.specify', 'kortex', 'scripts', 'worker-a.mjs'), "console.log('worker-a output');\n");
  await fs.writeFile(path.join(repo, '.specify', 'kortex', 'scripts', 'worker-b.mjs'), "console.log('worker-b output');\n");
  return repo;
}

async function writePlan(repo, plan) {
  const planPath = path.join(repo, 'plan.json');
  const runRoot = path.join(repo, '.specify', 'workflows', 'runs', plan.run_id);
  await fs.writeFile(planPath, JSON.stringify(plan));
  return { planPath, runRoot };
}

test('runs two allowlisted workers in parallel and records redacted telemetry', async () => {
  const repo = await fixtureRepo();
  const { planPath, runRoot } = await writePlan(repo, {
    run_id: 'run-test-001',
    workflow_id: 'kortexos-workflow-v1',
    max_workers: 2,
    workers: [
      { id: 'a', command: ['node', '.specify/kortex/scripts/worker-a.mjs'], write_set: [] },
      { id: 'b', command: ['node', '.specify/kortex/scripts/worker-b.mjs'], write_set: [] }
    ]
  });

  const report = await runPlan({ repo, planPath, runRoot });
  const state = JSON.parse(await fs.readFile(path.join(runRoot, 'state.json'), 'utf8'));
  const events = (await fs.readFile(path.join(runRoot, 'log.jsonl'), 'utf8')).trim().split('\n').map(JSON.parse);

  assert.equal(report.status, 'completed');
  assert.equal(state.status, 'completed');
  assert.deepEqual(state.workers.map(worker => worker.status).sort(), ['completed', 'completed']);
  assert.equal(events.filter(event => event.event === 'worker_completed').length, 2);
  assert.ok(events.every(event => !('stdout' in event) && !('stderr' in event)));
});

test('fails the run when one worker exits non-zero and records no approval', async () => {
  const repo = await fixtureRepo();
  await fs.writeFile(path.join(repo, '.specify', 'kortex', 'scripts', 'worker-fail.mjs'), "console.error('secret-like output'); process.exit(7);\n");
  const { planPath, runRoot } = await writePlan(repo, {
    run_id: 'run-test-002',
    workflow_id: 'kortexos-workflow-v1',
    max_workers: 2,
    workers: [
      { id: 'ok', command: ['node', '.specify/kortex/scripts/worker-a.mjs'], write_set: [] },
      { id: 'fail', command: ['node', '.specify/kortex/scripts/worker-fail.mjs'], write_set: [] }
    ]
  });

  const report = await runPlan({ repo, planPath, runRoot });
  const state = JSON.parse(await fs.readFile(path.join(runRoot, 'state.json'), 'utf8'));
  const log = await fs.readFile(path.join(runRoot, 'log.jsonl'), 'utf8');

  assert.equal(report.status, 'failed');
  assert.equal(state.status, 'failed');
  assert.match(log, /"worker_id":"fail"/);
  assert.doesNotMatch(log, /secret-like output/);
});

test('blocks plans that exceed the two-worker safety limit', async () => {
  const repo = await fixtureRepo();
  const { planPath, runRoot } = await writePlan(repo, {
    run_id: 'run-test-003',
    workflow_id: 'kortexos-workflow-v1',
    max_workers: 3,
    workers: [
      { id: 'a', command: ['node', '.specify/kortex/scripts/worker-a.mjs'], write_set: [] },
      { id: 'b', command: ['node', '.specify/kortex/scripts/worker-b.mjs'], write_set: [] },
      { id: 'c', command: ['node', '.specify/kortex/scripts/worker-a.mjs'], write_set: [] }
    ]
  });

  await assert.rejects(() => runPlan({ repo, planPath, runRoot }), /limited to 2 workers/);
  await assert.rejects(() => fs.access(runRoot));
});

test('blocks any worker with a write set in the read-only runner', async () => {
  const repo = await fixtureRepo();
  const { planPath, runRoot } = await writePlan(repo, {
    run_id: 'run-test-004',
    workflow_id: 'kortexos-workflow-v1',
    max_workers: 2,
    workers: [
      { id: 'a', command: ['node', '.specify/kortex/scripts/worker-a.mjs'], write_set: ['docs/report.md'] }
    ]
  });

  await assert.rejects(() => runPlan({ repo, planPath, runRoot }), /non-empty write_set/);
  await assert.rejects(() => fs.access(runRoot));
});
