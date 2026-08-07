#!/usr/bin/env node
'use strict';

// PostToolUse hook (kortex-pwa-architect, Fatia 7.4).
// Sinaliza (nao bloqueia — a edicao ja ocorreu) tags HTML nativas
// (<button>, <input>) em arquivos .jsx fora de frontend/src/ui/primitives,
// violando "a interface (PWA) DEVE usar exclusivamente os componentes
// primitivos do Kortex Design System... nunca tags HTML nativas"
// (AGENTS.md, Invariantes; kortex-pwa-architect, Restricoes criticas).
//
// Escopo literal do criterio de aceite da Fatia 7.4: <button> e <input>
// (os exemplos explicitos do spec). O spec usa "etc." para outras tags
// nativas (ex.: <select>, <textarea>) sem listar quais — nao expandido
// aqui para nao inventar escopo; extensao fica para decisao explicita
// futura do Platform Owner.

const fs = require('fs');
const path = require('path');

const JSX_FILE_RE = /\.jsx$/i;
const PRIMITIVES_DIR_RE = /[\\/]frontend[\\/]src[\\/]ui[\\/]primitives[\\/]/i;
// Sem a flag /i: tags nativas HTML sao sempre minusculas; componentes
// do Design System sao PascalCase (<Button>, <Input>) — a diferenca de
// caixa e o proprio sinal que distingue nativo de componente.
const NATIVE_TAG_RE = /<(button|input)\b/;

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
  if (!['Edit', 'Write', 'MultiEdit'].includes(toolName)) {
    process.exit(0);
  }

  const filePath = (input.tool_input && input.tool_input.file_path) || '';
  if (!filePath || !JSX_FILE_RE.test(filePath) || PRIMITIVES_DIR_RE.test(filePath)) {
    process.exit(0);
  }

  let content;
  try {
    content = fs.readFileSync(filePath, 'utf-8');
  } catch {
    process.exit(0);
  }

  const lines = content.split('\n');
  const findings = [];
  lines.forEach((line, idx) => {
    const match = line.match(NATIVE_TAG_RE);
    if (match) {
      findings.push(`${path.basename(filePath)}:${idx + 1}: <${match[1]}> nativo — ${line.trim()}`);
    }
  });

  if (findings.length > 0) {
    console.error('[kortex-pwa-architect] Tag HTML nativa fora do Kortex Design System (nao bloqueado, so sinalizado — a edicao ja foi aplicada):');
    findings.forEach((f) => console.error(`  - ${f}`));
    console.error('Use os componentes de frontend/src/ui/primitives/ (ex.: <Button>, <Input>) em vez de tags nativas (AGENTS.md, Invariantes).');
    process.exit(2);
  }

  process.exit(0);
}

main();
