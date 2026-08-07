# Onda 1 — Verificação da correção

Data: 2026-07-26
Escopo: blockers de DEC-36; implementação autorizada por DEC-38.

## Veredito local

**REAL — os três blockers técnicos foram corrigidos e testados em banco local descartável.**

| Achado | Correção comprovada |
|---|---|
| Depósito podia ser capturado por comanda não relacionada | Hold ganha snapshots imutáveis de cliente/serviço/profissional; `POST /appointments/:id/checkout` deriva a identidade no servidor e grava FKs de pedido–agendamento–hold. Walk-in rejeita `appointment_id`. |
| `released` e `expired` não transitavam | Trigger transacional muda hold/intento em cancelamento, no-show e expiração fail-closed; replanejamento explícito libera e recria o hold sob idempotência. |
| Dead-letter PSP não era reprocessado | A ingestão única por RPC volta a tentar a associação em redelivery e preserva tentativa/erro quando ainda não houver intent. |
| Autorização formal da Etapa 8 ausente | DEC-38 regulariza o escopo forward-only; DEC-39 registra a execução local. |

## Evidência executada

- `supabase db reset --local`: migrations até `20260726204000` aplicadas sem erro.
- `supabase test db --local` nas seis suites corretivas: **35/35 pgTAP PASS**.
- `supabase db lint --local`: **sem erros ou warnings**.
- `backend`: **297/297 testes PASS**; ESLint: 0 erros, 1 warning pré-existente fora do escopo (`fase9.test.js`).
- `frontend`: **106/106 testes PASS**; lint: 0 erros, 1 warning pré-existente (`ToastContext.jsx`); build Vite/PWA concluído.
- Testes de integração diretamente no fluxo corrigido: 13/13 PASS (checkout de agendamento/walk-in, no-show, replanejamento e webhook).

## Gate ainda necessário

Este documento não autoriza deploy. Antes de `staging`, executar preflight de `deposit_holds`: a migration deliberadamente recusa registros legados cujo cliente, serviço ou profissional não possam ser demonstrados sem inferência. Depois, homologar em `staging` e submeter ao Environment Guardian e ao Delivery Guardian antes de qualquer promoção para `main`/produção.

## Tentativa de homologação em staging — BLOQUEADA (2026-07-26)

- A CI do commit `0803ac2` concluiu com sucesso: Security & Linting, Supabase & Backend Tests e Frontend Build & Test.
- A PWA de staging respondeu `200`, porém o serviço `kortex-api-staging` está **suspenso por billing** no Render.
- O último deploy live do backend é o commit `9abada1`; portanto, `0803ac2` não está implantado no backend de staging.
- Não foram aplicadas migrations nem executados fluxos autenticados contra staging: fazê-lo sem API ativa não seria homologação válida.

Condição para retomar: reativar o serviço `kortex-api-staging`, confirmar o deploy automático de `0803ac2`, executar o preflight de holds legados e então rodar os cenários funcionais de checkout, lifecycle, replanejamento e reprocessamento de webhook.
