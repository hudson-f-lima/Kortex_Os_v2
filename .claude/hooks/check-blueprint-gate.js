#!/usr/bin/env node
'use strict';

// PreToolUse hook (kortex-blueprint-architect, Fatia 7.5).
// Bloqueia criar/editar arquivo em supabase/migrations/*.sql sem uma
// referencia (em comentario) a um documento de Blueprint que exista de
// fato no repo. Sinal escolhido explicitamente pelo Platform Owner
// (decisao registrada no handoff da Fatia 7.5): cabecalho/comentario na
// propria migration referenciando o caminho do Blueprint — nao branch
// nem existencia de issue.

const fs = require('fs');
const path = require('path');

const MIGRATION_FILE_RE = /supabase[\\/]migrations[\\/].*\.sql$/i;
// Casa a convencao ja usada nas migrations reais deste repo, ex.:
// "-- Implementa docs/waves/onda-4-calendar-availability/KORTEXOS_5_1_2_BLUEPRINT_ONDA_4.md"
// Nao exige a palavra literal "Blueprint:" — so um caminho docs/.../BLUEPRINT*.md.
const BLUEPRINT_REF_RE = /docs[\\/][\w\-.\\/]*BLUEPRINT[\w\-]*\.md/i;

function readStdin() {
  try {
    return fs.readFileSync(0, 'utf-8');
  } catch {
    return '';
  }
}

function findRepoRoot(startDir) {
  let dir = startDir;
  for (let i = 0; i < 20; i++) {
    if (fs.existsSync(path.join(dir, '.git'))) return dir;
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return startDir;
}

function checkContentForBlueprint(content, repoRoot) {
  const match = content.match(BLUEPRINT_REF_RE);
  if (!match) {
    return { ok: false, reason: 'nenhuma referencia a um Blueprint (caminho docs/.../BLUEPRINT*.md) encontrada em comentario' };
  }
  const refPath = match[0].replace(/\\/g, '/');
  const abs = path.join(repoRoot, refPath);
  if (!fs.existsSync(abs)) {
    return { ok: false, reason: `referencia "${refPath}" encontrada, mas esse arquivo nao existe no repo` };
  }
  return { ok: true, refPath };
}

function main() {
  let input;
  try {
    input = JSON.parse(readStdin() || '{}');
  } catch {
    process.exit(0);
  }

  const toolName = input.tool_name || '';
  if (!['Write', 'Edit', 'MultiEdit'].includes(toolName)) {
    process.exit(0);
  }

  const filePath = (input.tool_input && input.tool_input.file_path) || '';
  if (!filePath || !MIGRATION_FILE_RE.test(filePath)) {
    process.exit(0);
  }

  const repoRoot = findRepoRoot(path.dirname(filePath));

  let contentToCheck;
  if (toolName === 'Write') {
    contentToCheck = (input.tool_input && input.tool_input.content) || '';
  } else {
    // Edit/MultiEdit: a referencia deveria ja existir no arquivo (escrita na criacao via Write).
    try {
      contentToCheck = fs.readFileSync(filePath, 'utf-8');
    } catch {
      // Arquivo ainda nao existe — Edit nao deveria chegar aqui; falha aberto por seguranca.
      process.exit(0);
    }
  }

  const result = checkContentForBlueprint(contentToCheck, repoRoot);
  if (!result.ok) {
    console.error(`[kortex-blueprint-architect] Bloqueado: ${path.basename(filePath)} sem referencia valida a Blueprint aprovado.`);
    console.error(`Motivo: ${result.reason}.`);
    console.error('Adicione um comentario referenciando o caminho real do Blueprint (ex.: "-- Implementa docs/waves/onda-N/BLUEPRINT_ONDA_N.md") antes de escrever/editar esta migration.');
    process.exit(2);
  }

  process.exit(0);
}

main();
