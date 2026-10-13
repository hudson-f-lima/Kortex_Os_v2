import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.argv[2] || '.specify/kortex');
const allowed = path.basename(root) === 'kortex' && fs.existsSync(path.join(root, 'integration.json'));
if (!allowed) { console.error(JSON.stringify({ status: 'BLOCKED', reason: 'rollback target is not the explicit .specify/kortex integration root' })); process.exit(2); }
console.log(JSON.stringify({ status: 'DRY_RUN', target: root, would_remove: [root], forbidden: ['repo root', 'backend', 'frontend', 'supabase', 'docs', 'issues', '.git'], destructive_action_executed: false }, null, 2));
