#!/usr/bin/env node
'use strict';

// PreToolUse hook (kortex-delivery-guardian, Fatia 7.1).
// Bloqueia `git commit` cujo diff staged contenha padrao de segredo/chave/token.
// Complementa (nao substitui) o Gitleaks do CI: este roda antes do push, o CI depois.

const { execSync } = require('child_process');
const fs = require('fs');

function readStdin() {
  try {
    return fs.readFileSync(0, 'utf-8');
  } catch {
    return '';
  }
}

const SECRET_PATTERNS = [
  { name: 'AWS Access Key ID', re: /AKIA[0-9A-Z]{16}/ },
  { name: 'Bloco de chave privada', re: /-----BEGIN (RSA |EC |OPENSSH |DSA |)PRIVATE KEY-----/ },
  { name: 'Token GitHub', re: /gh[pousr]_[A-Za-z0-9]{36,}/ },
  { name: 'Token Slack', re: /xox[baprs]-[A-Za-z0-9-]{10,}/ },
  { name: 'Chave Stripe', re: /sk_(live|test)_[A-Za-z0-9]{16,}/ },
  {
    name: 'Atribuicao genérica de segredo',
    re: /\b(SECRET|TOKEN|API_KEY|APIKEY|PASSWORD|ACCESS_KEY|PRIVATE_KEY|SERVICE_ROLE_KEY)\w*\s*[:=]\s*['"][A-Za-z0-9/+=_.\-]{16,}['"]/i,
  },
];

function main() {
  let input;
  try {
    input = JSON.parse(readStdin() || '{}');
  } catch {
    process.exit(0);
  }

  const toolName = input.tool_name || '';
  const command = (input.tool_input && input.tool_input.command) || '';

  if (toolName !== 'Bash' || typeof command !== 'string') {
    process.exit(0);
  }

  if (!/\bgit\s+commit\b/.test(command)) {
    process.exit(0);
  }

  let diff;
  try {
    diff = execSync('git diff --cached', { encoding: 'utf-8', maxBuffer: 20 * 1024 * 1024 });
  } catch {
    // Falha ao computar o diff (ex.: fora de um repo git) nao deve travar o commit.
    process.exit(0);
  }

  const lines = diff.split('\n');
  const findings = [];
  let currentFile = '(arquivo desconhecido)';

  for (const line of lines) {
    const fileMatch = line.match(/^\+\+\+ b\/(.+)$/);
    if (fileMatch) {
      currentFile = fileMatch[1];
      continue;
    }
    if (!line.startsWith('+') || line.startsWith('+++')) continue;
    const added = line.slice(1);
    for (const pattern of SECRET_PATTERNS) {
      if (pattern.re.test(added)) {
        findings.push(`${currentFile}: ${pattern.name}`);
      }
    }
  }

  if (findings.length > 0) {
    const unique = [...new Set(findings)];
    console.error('[kortex-delivery-guardian] Commit bloqueado: padrao de segredo detectado no diff staged.');
    unique.forEach((f) => console.error(`  - ${f}`));
    console.error('Remova o segredo do stage (git restore --staged <arquivo>) antes de commitar. Este hook complementa o Gitleaks do CI (roda antes do push; o CI roda depois do push).');
    process.exit(2);
  }

  process.exit(0);
}

main();
