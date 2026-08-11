import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const repo = path.resolve(process.argv[2] || process.cwd());
const fullSources = ['AGENTS.md', 'docs/INDEX.md', 'docs/waves/KORTEXOS_5_1_2_TRUTH_MAP.md', 'docs/waves/KORTEXOS_5_1_2_MIGRATION_MAP.md', 'docs/architecture/governance/KORTEXOS_DOCUMENTATION_AUTOMATION_PROTOCOL.md', 'docs/architecture/adr/0024-adocao-controlada-spec-kit-fluxo-agentico.md'];
const domains = { audit: fullSources.slice(0, 5), blueprint: [fullSources[0], fullSources[1], fullSources[2], fullSources[3]], sql: [fullSources[0], fullSources[1], fullSources[3]], express: [fullSources[0], fullSources[1], fullSources[2]], pwa: [fullSources[0], fullSources[1]], qa: fullSources, promotion: [fullSources[0], fullSources[1], fullSources[3], fullSources[5]] };
const domain = process.argv[3] || 'audit';
if (!domains[domain]) throw new Error(`unknown domain: ${domain}`);
const sources = domains[domain].map(relative => { const bytes = fs.readFileSync(path.join(repo, relative)); return { path: relative, bytes: bytes.length, sha256: crypto.createHash('sha256').update(bytes).digest('hex') }; });
console.log(JSON.stringify({ domain, progressive: true, source_count: sources.length, critical_rules_required: ['organization_id', 'RLS', 'service_role', 'Benchmark Gate', 'git fetch', 'Handoff'], sources }, null, 2));
