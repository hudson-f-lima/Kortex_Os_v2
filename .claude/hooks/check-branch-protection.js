#!/usr/bin/env node
'use strict';

// PreToolUse hook (kortex-environment-guardian, Fatia 7.2).
// Bloqueia `git commit`/`git push` executado diretamente na branch local
// `main` ou `staging` — toda mudanca deve nascer em branch de feature/fix
// e voltar via PR (ver AGENTS.md, Processo MAS / kortex-environment-guardian).
//
// Excecao (achada em uso real, 2026-08-04): `git push --delete <branch>`
// (ou `-d`, ou refspec `:branch`) so apaga uma ref remota — nao publica
// nenhum commit na branch atual. Bloquear isso pelo HEAD atual e falso
// positivo (ex.: limpar branches remotas ja mergeadas estando em
// `staging`). A checagem para delete passa a olhar o(s) nome(s) da branch
// sendo apagada, nao o HEAD — e continua bloqueando se alguem tentar
// apagar `main`/`staging` remotamente, que e uma acao real e mais grave.

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

function extractDeletedRefs(command) {
  const refs = [];

  const flagMatch = command.match(/(?:--delete|(?:^|\s)-d)\b\s+([^\n|&;]+)/);
  if (flagMatch) {
    flagMatch[1].split(/\s+/).forEach((tok) => {
      const clean = tok.trim().replace(/^origin\//, '');
      if (clean && !clean.startsWith('-')) refs.push(clean);
    });
  }

  for (const m of command.matchAll(/(?:^|\s):([\w./-]+)/g)) {
    refs.push(m[1]);
  }

  return refs;
}

function isDeletePush(command) {
  return /\bgit\s+push\b/.test(command) && (/--delete\b/.test(command) || /(?:^|\s)-d\b/.test(command) || /(?:^|\s):[\w./-]+/.test(command));
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

  if (isDeletePush(command)) {
    const deletedRefs = extractDeletedRefs(command);
    const deletesProtected = deletedRefs.some((ref) => PROTECTED_BRANCHES.has(ref));
    if (!deletesProtected) {
      // Deleta ref remota que nao e main/staging — nao afeta essas branches, permitido.
      process.exit(0);
    }
    console.error(`[kortex-environment-guardian] Bloqueado: "${command.trim()}" tenta apagar a branch remota protegida.`);
    console.error('Nunca apagar `main`/`staging` remotamente por comando direto — decisao exclusiva do Platform Owner.');
    process.exit(2);
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
