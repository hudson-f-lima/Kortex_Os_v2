import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const MAX_WORKERS = 2;
const SCRIPT_ROOT = path.join('.specify', 'kortex', 'scripts');
const RUNS_ROOT = path.join('.specify', 'workflows', 'runs');

function isWithin(parent, candidate) {
  const relative = path.relative(parent, candidate);
  return relative === '' || (!relative.startsWith('..') && !path.isAbsolute(relative));
}

function sha256(buffer) {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

function validateCommand(command, repo) {
  if (!Array.isArray(command) || command.length < 2 || command[0] !== 'node') {
    throw new Error('worker command must invoke node with an allowlisted local script');
  }

  const script = path.resolve(repo, command[1]);
  const scriptRoot = path.resolve(repo, SCRIPT_ROOT);
  if (!isWithin(scriptRoot, script) || path.extname(script) !== '.mjs') {
    throw new Error(`worker script is outside the allowlisted root: ${command[1]}`);
  }
}

function validatePlan(plan, repo, runRoot) {
  if (!plan || typeof plan !== 'object') throw new Error('fan-out plan must be an object');
  if (typeof plan.run_id !== 'string' || !plan.run_id) throw new Error('fan-out plan requires run_id');
  if (path.basename(runRoot) !== plan.run_id) throw new Error('run_root basename must match plan run_id');
  if (!Array.isArray(plan.workers) || plan.workers.length === 0) throw new Error('fan-out plan requires workers');
  const requestedWorkers = plan.max_workers ?? MAX_WORKERS;
  if (!Number.isInteger(requestedWorkers) || requestedWorkers < 1 || requestedWorkers > MAX_WORKERS || plan.workers.length > requestedWorkers) {
    throw new Error(`fan-out is limited to ${MAX_WORKERS} workers`);
  }

  const writes = [];
  for (const worker of plan.workers) {
    if (!worker || typeof worker.id !== 'string' || !worker.id) throw new Error('each worker requires a non-empty id');
    validateCommand(worker.command, repo);
    if (!Array.isArray(worker.write_set)) throw new Error(`worker ${worker.id} requires write_set`);
    if (worker.write_set.length > 0) throw new Error(`worker ${worker.id} has a non-empty write_set; read-only runner blocked`);
    for (const item of worker.write_set) writes.push({ worker: worker.id, item });
  }

  const seen = new Map();
  for (const { worker, item } of writes) {
    if (seen.has(item)) throw new Error(`overlapping write_set item: ${item}`);
    seen.set(item, worker);
  }
}

function runWorker({ worker, repo, appendEvent }) {
  return new Promise((resolve) => {
    const startedAt = Date.now();
    appendEvent({ event: 'worker_started', worker_id: worker.id, timestamp: new Date(startedAt).toISOString() });
    const stdout = [];
    const stderr = [];
    let settled = false;
    const finish = (status, exitCode, error) => {
      if (settled) return;
      settled = true;
      const stdoutBuffer = Buffer.concat(stdout);
      const stderrBuffer = Buffer.concat(stderr);
      const summary = {
        event: status === 'completed' ? 'worker_completed' : 'worker_failed',
        worker_id: worker.id,
        timestamp: new Date().toISOString(),
        duration_ms: Date.now() - startedAt,
        status,
        exit_code: exitCode,
        stdout_bytes: stdoutBuffer.length,
        stderr_bytes: stderrBuffer.length,
        stdout_sha256: sha256(stdoutBuffer),
        stderr_sha256: sha256(stderrBuffer)
      };
      if (error) summary.error_code = error.code || 'SPAWN_ERROR';
      appendEvent(summary);
      resolve({ id: worker.id, status, exit_code: exitCode, duration_ms: summary.duration_ms });
    };

    const [executable, ...args] = worker.command;
    const child = spawn(executable, args, { cwd: repo, shell: false, stdio: ['ignore', 'pipe', 'pipe'] });
    child.stdout.on('data', (chunk) => stdout.push(chunk));
    child.stderr.on('data', (chunk) => stderr.push(chunk));
    child.on('error', (error) => finish('failed', null, error));
    child.on('close', (code) => finish(code === 0 ? 'completed' : 'failed', code, null));
  });
}

export async function runPlan({ repo = '.', planPath, runRoot } = {}) {
  const absoluteRepo = path.resolve(repo);
  const absolutePlanPath = path.resolve(absoluteRepo, planPath || path.join('.specify', 'kortex', 'plans', 'read-only-evals.json'));
  const plan = JSON.parse(await fs.readFile(absolutePlanPath, 'utf8'));
  const absoluteRunRoot = path.resolve(absoluteRepo, runRoot || path.join(RUNS_ROOT, plan.run_id));
  const authorizedRunsRoot = path.resolve(absoluteRepo, RUNS_ROOT);
  if (!isWithin(authorizedRunsRoot, absoluteRunRoot) || absoluteRunRoot === authorizedRunsRoot) {
    throw new Error('run_root must be inside .specify/workflows/runs');
  }
  validatePlan(plan, absoluteRepo, absoluteRunRoot);

  await fs.mkdir(absoluteRunRoot, { recursive: true });
  const logPath = path.join(absoluteRunRoot, 'log.jsonl');
  const statePath = path.join(absoluteRunRoot, 'state.json');
  await fs.writeFile(logPath, '');
  let logTail = Promise.resolve();
  const appendEvent = (event) => {
    logTail = logTail.then(() => fs.appendFile(logPath, `${JSON.stringify(event)}\n`));
    return logTail;
  };
  const startedAt = Date.now();
  const baseState = {
    run_id: plan.run_id,
    workflow_id: plan.workflow_id || null,
    status: 'running',
    started_at: new Date(startedAt).toISOString(),
    workers: plan.workers.map((worker) => ({ id: worker.id, status: 'pending' }))
  };
  await fs.writeFile(statePath, JSON.stringify(baseState, null, 2));
  await appendEvent({ event: 'run_started', run_id: plan.run_id, workflow_id: plan.workflow_id || null, timestamp: baseState.started_at, worker_count: plan.workers.length });

  const workers = await Promise.all(plan.workers.map((worker) => runWorker({ worker, repo: absoluteRepo, appendEvent })));
  const status = workers.every((worker) => worker.status === 'completed') ? 'completed' : 'failed';
  const finishedAt = Date.now();
  const state = {
    ...baseState,
    status,
    finished_at: new Date(finishedAt).toISOString(),
    duration_ms: finishedAt - startedAt,
    workers
  };
  await appendEvent({ event: 'run_finished', run_id: plan.run_id, timestamp: state.finished_at, status, duration_ms: state.duration_ms });
  await logTail;
  await fs.writeFile(statePath, JSON.stringify(state, null, 2));
  return { run_id: plan.run_id, workflow_id: plan.workflow_id || null, status, duration_ms: state.duration_ms, workers };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  const args = process.argv.slice(2);
  const valueFor = (name) => {
    const index = args.indexOf(name);
    return index >= 0 ? args[index + 1] : undefined;
  };
  runPlan({ repo: valueFor('--repo') || '.', planPath: valueFor('--plan'), runRoot: valueFor('--run-root') })
    .then((report) => {
      console.log(JSON.stringify(report, null, 2));
      if (report.status !== 'completed') process.exitCode = 1;
    })
    .catch((error) => {
      console.error(error.message);
      process.exitCode = 1;
    });
}
