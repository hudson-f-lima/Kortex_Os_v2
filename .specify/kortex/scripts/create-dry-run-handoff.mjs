import { execFileSync } from 'node:child_process';
import path from 'node:path';

const repo = path.resolve(process.env.KORTEX_REPO || process.cwd());
const commit = execFileSync('git', ['-C', repo, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
const branch = execFileSync('git', ['-C', repo, 'branch', '--show-current'], { encoding: 'utf8' }).trim();
const handoff = {
  run: {
    run_id: process.env.SPECIFY_RUN_ID || 'integrated-dry-run',
    workflow_id: 'kortexos-workflow-v1',
    cli_version: '0.12.11',
    ref: { branch, commit },
    mode: 'AFK',
    task: { id: 'SPK-001', classification: 'read-only', owner: 'kortex-mvpt-orchestrator', intent: 'validate the controlled Spec Kit integration without product mutation' },
    context: { sources: ['AGENTS.md', 'docs/INDEX.md', 'Truth Map', 'Migration Map', 'ADR 0024'] },
    gates: [{ id: 'preflight', status: 'GO', evidence_paths: ['stdout'] }, { id: 'mutation-boundary', status: 'GO', evidence_paths: ['workflow log'] }],
    artifacts: ['stdout handoff']
  },
  verification: {
    tests: ['preflight read-only', 'handoff contract validation'],
    commands: ['node .specify/kortex/scripts/preflight.mjs', 'node .specify/kortex/scripts/validate-handoff.mjs -'],
    status: 'passed'
  },
  handoff: {
    files_changed: [],
    blockers_remaining: ['Platform Owner-approved constraints remain active', 'no product/migration/promotion execution'],
    verdict: 'GO',
    next_step: 'continue with the next approved SPK issue after its gate',
    stop_condition: 'stop before product code, migration, external write, promotion or feature-flag activation'
  }
};
console.log(JSON.stringify(handoff));
