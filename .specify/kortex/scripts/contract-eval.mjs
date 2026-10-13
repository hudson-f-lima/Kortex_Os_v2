const commit = 'a'.repeat(40);
function validCase(index, classification = index % 2 ? 'read-only' : 'mechanical') {
  const mode = ['product-behavior', 'migration', 'promotion'].includes(classification) ? 'HITL' : 'AFK';
  const gates = [{ id: 'preflight', status: 'GO', evidence_paths: ['preflight.json'] }];
  if (classification === 'product-behavior') gates.push({ id: 'benchmark', status: 'GO', evidence_paths: ['benchmark.md'] });
  return { run: { run_id: `run-${String(index).padStart(6, '0')}`, workflow_id: 'kortexos-workflow-v1', cli_version: '0.12.11', ref: { branch: 'feature', commit }, mode, task: { id: `SPK-${index}`, classification, owner: 'kortex-mvpt-orchestrator', intent: 'bounded workflow contract' }, context: { sources: ['AGENTS.md', 'docs/INDEX.md'] }, gates, artifacts: ['handoff.json'] }, verification: { tests: ['contract'], commands: ['node contract-eval.mjs'], status: 'passed' }, handoff: { files_changed: [], blockers_remaining: [], verdict: 'GO', next_step: 'continue bounded flow', stop_condition: 'stop at any non-green gate' } };
}
function errors(c) {
  const out = [], r = c?.run, t = r?.task, h = c?.handoff, v = c?.verification;
  if (!r?.run_id) out.push('run.run_id');
  if (r?.cli_version !== '0.12.11') out.push('run.cli_version');
  if (!/^[0-9a-f]{40}$/.test(r?.ref?.commit ?? '')) out.push('run.ref.commit');
  if (!r?.context?.sources?.length) out.push('run.context.sources');
  if (!t?.owner) out.push('run.task.owner');
  if (!['AFK', 'HITL'].includes(r?.mode)) out.push('run.mode');
  if (['product-behavior', 'migration', 'promotion'].includes(t?.classification) && r.mode !== 'HITL') out.push('run.mode.requires.HITL');
  if (!r?.gates?.length) out.push('run.gates');
  for (const gate of r?.gates ?? []) if (!gate.evidence_paths?.length) out.push(`gate.${gate.id}.evidence_paths`);
  if (t?.classification === 'product-behavior' && !r.gates.some(g => g.id === 'benchmark' && g.status === 'GO')) out.push('gate.benchmark');
  if (!['passed', 'failed', 'blocked'].includes(v?.status)) out.push('verification.status');
  if (v?.status === 'passed' && h?.verdict !== 'GO') out.push('handoff.verdict.matches.verification');
  if (!h?.stop_condition) out.push('handoff.stop_condition');
  if (!['GO', 'NO-GO', 'PARTIAL', 'BLOCKED'].includes(h?.verdict)) out.push('handoff.verdict');
  return out;
}
const valid = Array.from({ length: 20 }, (_, i) => validCase(i + 1, i === 5 ? 'product-behavior' : i === 6 ? 'migration' : i === 7 ? 'promotion' : undefined));
const invalid = [
  ['missing-run-id', c => { delete c.run.run_id; return 'run.run_id'; }], ['wrong-cli-version', c => { c.run.cli_version = 'main'; return 'run.cli_version'; }], ['bad-commit', c => { c.run.ref.commit = 'deadbeef'; return 'run.ref.commit'; }], ['missing-context', c => { c.run.context.sources = []; return 'run.context.sources'; }], ['missing-owner', c => { delete c.run.task.owner; return 'run.task.owner'; }], ['invalid-mode', c => { c.run.mode = 'AUTO'; return 'run.mode'; }], ['product-without-hitl', c => { c.run.task.classification = 'product-behavior'; c.run.mode = 'AFK'; return 'run.mode.requires.HITL'; }], ['product-without-benchmark', c => { c.run.task.classification = 'product-behavior'; c.run.mode = 'HITL'; c.run.gates = [{ id: 'preflight', status: 'GO', evidence_paths: ['preflight.json'] }]; return 'gate.benchmark'; }], ['gate-without-evidence', c => { c.run.gates[0].evidence_paths = []; return 'gate.preflight.evidence_paths'; }], ['missing-stop-condition', c => { delete c.handoff.stop_condition; return 'handoff.stop_condition'; }]
].map(([name, mutate], index) => { const contract = validCase(100 + index); return { name, contract, expected: mutate(contract) }; });
const validPassed = valid.filter(c => errors(c).length === 0).length;
const invalidBlocked = invalid.filter(({ contract, expected }) => errors(contract).includes(expected)).length;
const report = { cli_version: '0.12.11', valid_cases: 20, valid_passed: validPassed, invalid_cases: 10, invalid_blocked_at_expected_field: invalidBlocked, status: validPassed === 20 && invalidBlocked === 10 ? 'GO' : 'NO-GO' };
console.log(JSON.stringify(report, null, 2));
if (report.status !== 'GO') process.exit(1);
