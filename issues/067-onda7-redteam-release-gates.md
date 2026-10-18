---
title: "Onda 7 — Red Team e gates de promoção"
status: "PROPOSED"
stage: "ISSUE"
governance_ref: ["DEC-69"]
upstream_doc: "docs/waves/onda-7-agenda-drag-resize/BLUEPRINT_ONDA_7_RESIZE.md"
last_updated: "2026-10-18"
---

# 067 — Verificação adversarial e homologação

Reexecutar em banco descartável `supabase db reset`, pgTAP completo, lint SQL, backend e frontend, nessa ordem; Red Team independente ataca DML direto, tenant/unidade, corrida, liberação de lock, ativação com backfill, DST/folgas parciais, idempotência e regressões financeiras. Registrar resultados brutos. Após `GO`, PR/CI e Environment Guardian para `staging`; homologação autenticada com flag controlada e Delivery Guardian antes de qualquer `main`/produção. Nenhum gate é aprovado por relato.

**Aceite:** zero falha crítica/alta sem mitigação, todas as suítes verdes e vereditos por ambiente documentados. Se o projeto de staging ou runtime local estiver indisponível, classificar `BLOQUEADO`, sem declarar conclusão.

Blocked by: [062](062-onda7-resource-requirement-schema.md) a [066](066-onda7-agenda-resize-ui.md).
