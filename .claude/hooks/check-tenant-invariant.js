#!/usr/bin/env node
'use strict';

// PostToolUse hook (kortex-express-architect, Fatia 7.3).
// Sinaliza (nao bloqueia — a edicao ja ocorreu) uso de req.body.tenant_id /
// req.query.tenant_id como fonte de tenant em arquivos de rota (*.route.js
// sob backend/), o que viola "tenant deriva de membership autenticada,
// nunca de body/query isoladamente" (AGENTS.md, Invariantes).
//
// Escopo literal do criterio de aceite da Fatia 7.3: apenas tenant_id.
// Nota: o campo real de tenant nesta base e organization_id (AGENTS.md
// "Toda tabela de negocio possui organization_id"; kortex-express-architect
// proibe aceitar X-Organization-Id sem validar membership) — este hook,
// como especificado, NAO cobre req.body.organization_id/req.query.organization_id.

const fs = require('fs');
const path = require('path');

const ROUTE_FILE_RE = /backend[\\/].*\.route\.js$/i;
const TENANT_SOURCE_RE = /req\s*(?:\.\s*body\s*(?:\.\s*tenant_id\b|\[\s*['"]tenant_id['"]\s*\])|\.\s*query\s*(?:\.\s*tenant_id\b|\[\s*['"]tenant_id['"]\s*\]))/;

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
  if (!filePath || !ROUTE_FILE_RE.test(filePath)) {
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
    if (TENANT_SOURCE_RE.test(line)) {
      findings.push(`${path.basename(filePath)}:${idx + 1}: ${line.trim()}`);
    }
  });

  if (findings.length > 0) {
    console.error('[kortex-express-architect] Invariante de tenant violado em arquivo de rota (nao bloqueado, so sinalizado — a edicao ja foi aplicada):');
    findings.forEach((f) => console.error(`  - ${f}`));
    console.error('Tenant DEVE derivar de membership autenticada (AGENTS.md, Invariantes) — nunca de req.body/req.query isoladamente.');
    process.exit(2);
  }

  process.exit(0);
}

main();
