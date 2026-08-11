import fs from 'node:fs';

const file = process.argv[2];
if (!file) throw new Error('handoff JSON path is required');
const value = JSON.parse(file === '-' ? fs.readFileSync(0, 'utf8') : fs.readFileSync(file, 'utf8'));
const required = [
  ['run', 'run_id'], ['run', 'workflow_id'], ['run', 'cli_version'], ['run', 'ref'],
  ['verification', 'tests'], ['verification', 'commands'], ['verification', 'status'],
  ['handoff', 'files_changed'], ['handoff', 'blockers_remaining'], ['handoff', 'verdict'],
  ['handoff', 'next_step'], ['handoff', 'stop_condition']
];
const forbidden = /(?:AKIA[0-9A-Z]{16}|Bearer\s+[A-Za-z0-9._-]+|BEGIN\s+(?:RSA|EC|OPENSSH)\s+PRIVATE KEY|password\s*[:=])/i;
const serialized = JSON.stringify(value);
const missing = required.filter(([section, field]) => value?.[section]?.[field] === undefined).map(([section, field]) => `${section}.${field}`);
const errors = [];
if (missing.length) errors.push(`missing: ${missing.join(', ')}`);
if (value?.run?.cli_version !== '0.12.11') errors.push('cli_version must be 0.12.11');
if (forbidden.test(serialized)) errors.push('secret-like content detected');
if (!Array.isArray(value?.verification?.tests) || value.verification.tests.length === 0) errors.push('verification.tests must be non-empty');
if (errors.length) { console.error(JSON.stringify({ status: 'BLOCKED', errors }, null, 2)); process.exit(2); }
console.log(JSON.stringify({ status: 'GO', handoff: file, verdict: value.handoff.verdict }, null, 2));
