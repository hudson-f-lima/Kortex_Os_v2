// Issue 043 — CSP e X-Frame-Options no PWA (Render). Valida a configuração
// declarativa em render.yaml, não o deploy ao vivo: o Aceite completo da
// issue (curl -sI contra a URL real) só pode ser verificado depois do
// deploy, fora do alcance de um teste local. Este arquivo é o gate
// mecânico que roda antes disso — sem ele, um erro de digitação ou origem
// esquecida no CSP só apareceria em produção.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const repoRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const renderYaml = readFileSync(join(repoRoot, 'render.yaml'), 'utf8');

// Extração deliberadamente simples (regex sobre texto), no mesmo espírito
// dos hooks determinísticos do projeto (.claude/hooks) — este arquivo é
// pequeno e estável o bastante para não justificar uma dependência de
// parser YAML só para este teste.
function extractServiceBlock(name) {
  const serviceStart = new RegExp(`^ {4}name: ${name}$`, 'm');
  const startMatch = serviceStart.exec(renderYaml);
  assert.ok(startMatch, `service '${name}' not found in render.yaml`);
  const rest = renderYaml.slice(startMatch.index);
  const nextServiceIndex = rest.slice(1).search(/^ {2}- type: web$/m);
  return nextServiceIndex === -1 ? rest : rest.slice(0, nextServiceIndex + 1);
}

function extractHeaderValue(block, headerName) {
  // Cada header é sua própria entrada `- path: /*` seguida de `name:`/`value:`
  // (formato real confirmado contra render.yaml de terceiros no GitHub —
  // Render usa `name`, não `key`, ao contrário do que a documentação
  // resumida sugeria).
  const pattern = new RegExp(
    `- path: /\\*\\s*\\n\\s*name: ${headerName}\\s*\\n\\s*value: (.+)`,
  );
  const match = pattern.exec(block);
  return match ? match[1].trim().replace(/^"(.*)"$/, '$1') : null;
}

const services = [
  {
    name: 'kortex-pwa',
    apiOrigin: 'https://kortex-os-v2.onrender.com',
    supabaseOrigin: 'https://kpedsuklnedlhjvadiyc.supabase.co',
  },
  {
    name: 'kortex-pwa-staging',
    apiOrigin: 'https://kortex-api-staging.onrender.com',
    supabaseOrigin: 'https://hyzoocmmtmjlgdyifwhu.supabase.co',
  },
];

for (const { name, apiOrigin, supabaseOrigin } of services) {
  test(`${name} declares a Content-Security-Policy header on path /*`, () => {
    const block = extractServiceBlock(name);
    const csp = extractHeaderValue(block, 'Content-Security-Policy');
    assert.ok(csp, `${name} is missing a Content-Security-Policy header entry`);
    assert.match(csp, /default-src 'self'/, `${name} CSP must restrict default-src to 'self'`);
  });

  test(`${name} CSP connect-src allows this environment's own API and Supabase origins`, () => {
    const block = extractServiceBlock(name);
    const csp = extractHeaderValue(block, 'Content-Security-Policy');
    assert.ok(csp, `${name} is missing a Content-Security-Policy header entry`);
    assert.match(
      csp,
      new RegExp(`connect-src[^;]*${apiOrigin.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`),
      `${name} CSP connect-src must allow its own API origin (${apiOrigin}) or auth/session calls break`,
    );
    assert.match(
      csp,
      new RegExp(`connect-src[^;]*${supabaseOrigin.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`),
      `${name} CSP connect-src must allow its own Supabase origin (${supabaseOrigin}) or login breaks`,
    );
  });

  test(`${name} declares X-Frame-Options: DENY on path /*`, () => {
    const block = extractServiceBlock(name);
    const xfo = extractHeaderValue(block, 'X-Frame-Options');
    assert.equal(xfo, 'DENY', `${name} must set X-Frame-Options: DENY`);
  });
}
