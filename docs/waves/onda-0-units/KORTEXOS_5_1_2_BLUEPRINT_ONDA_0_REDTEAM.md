# QA Red Team — Blueprint Onda 0

**Data:** 2026-07-21 (gates originais), revisado em 2026-07-22 contra o desenho atualizado (DEC-31). **Nenhum SQL, migration ou teste de produto foi executado neste gate documental** — a versão de 2026-07-21 desta revisão ficou presa numa branch nunca mesclada junto com uma alegação de "ambiente testado e saudável" que não se confirmou; esta reavaliação não herda essa alegação.

## GATES_EVALUATION

| Gate | Veredito | Evidência / motivo |
|---|---|---|
| Escopo/cânone | PASS | Onda limitada a D01 e coerente com Migration Map v1.2/DEC-28. |
| Blueprint | PASS | §3.1 define colunas, tipos, PKs, FKs, checks e índices para todos os objetos. |
| Tenant | PASS | §3.2 e §6.1 definem FKs compostas, enforcement concorrente, RLS e negação cross-unit. |
| Agenda | PASS | §4.1 e §6.1 definem vínculo ativo, imutabilidade e falhas fail-closed via trigger, sem tocar as RPCs existentes. |
| Dinheiro/estoque | PASS | §4.1 define FKs pai-filho, imutabilidade e comandos de ajuste autorizados; trigger de default-fill evita reescrever `checkout_close`/`inventory_adjust`, reduzindo risco de regressão numa função de 150+ linhas já coberta por pgTAP. |
| Supabase | BLOQUEADO | Reset, advisors, pgTAP e ataque RLS são evidências obrigatórias da próxima etapa, depois de SQL aprovado — nenhuma dessas evidências é reivindicada aqui. |
| Backend/PWA | PASS | §5–§7 definem timezone fixa (sem UI nova), fallback via trigger, rejeição de `unit_id` público e nenhuma tela nesta onda; confirmado por leitura direta de `organizations.route.js` e `OrganizationModal.jsx` que nenhum chamador existente quebra. |
| Auditoria | PASS | §3.1 e §6.1 definem modelo físico, allowlist, append-only, visibilidade e exclusão de PII. |

## VULNERABILITIES_FOUND

Nenhuma vulnerabilidade de desenho aberta. Um risco da versão anterior (reescrever RPCs de checkout/agenda/estoque para setar `unit_id`, arriscando regressão financeira) foi eliminado trocando por trigger `BEFORE INSERT` de default-fill — decisão registrada em DEC-31.

## Próximas evidências obrigatórias

- SQL Master gerado exclusivamente a partir deste Blueprint, com migrations criadas pela Supabase CLI (Migration 1 aditiva+backfill, Migration 2 hardening).
- Reset local, advisors, pgTAP, testes backend/frontend (regressão) e ataques cross-tenant/cross-unit — cada um verificado por chamada direta, nunca por relato de subagente (ver incidente registrado em `kortex-supabase-guard/SKILL.md`, item 6).

## VEREDITO

**GO para solicitar autorização explícita da Etapa 8 (SQL).** O Blueprint revisado passou na revisão de desenho. A implementação continua não autorizada até nova aprovação explícita do Platform Owner para SQL (DEC-32); os gates executáveis de Supabase/backend/PWA serão reavaliados após a implementação, com evidência própria.
