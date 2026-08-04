#!/usr/bin/env node
'use strict';

// PreToolUse hook (kortex-environment-guardian, Fatia 7.2).
// Bloqueia `git commit`/`git push` executado diretamente na branch local
// `main` ou `staging` — toda mudanca deve nascer em branch de feature/fix
// e voltar via PR (ver AGENTS.md, Processo MAS / kortex-environment-guardian).

const { execSync } = require('child_process');
const fs = require('fs');

const PROTECTED_BRANCHES = new Set(['main', 'staging']);

function readStdin() {
  try {
    return fs.readFileSync(0, 'utf-8');
  } catch {
    return '';
  }
}

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

  if (!/\bgit\s+(commit|push)\b/.test(command)) {
    process.exit(0);
  }

  let branch;
  try {
    branch = execSync('git rev-parse --abbrev-ref HEAD', { encoding: 'utf-8' }).trim();
  } catch {
    // Fora de um repo git ou HEAD desanexado: nao ha branch protegida a checar.
    process.exit(0);
  }

  if (PROTECTED_BRANCHES.has(branch)) {
    console.error(`[kortex-environment-guardian] Bloqueado: "${command.trim()}" executado diretamente na branch "${branch}".`);
    console.error('Toda mudanca nasce em branch de feature/fix e volta para staging via PR — nunca commit/push direto em main ou staging.');
    console.error('Crie uma branch dedicada (git checkout -b <nome> origin/staging) antes de commitar.');
    process.exit(2);
  }

  process.exit(0);
}

main();
