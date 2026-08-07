---
title: "Backlog — runtime do AppCliente e entrega FCM"
status: "DRAFT"
stage: "ISSUE"
governance_ref: ["DEC-56", "ADR-0023"]
upstream_doc: "docs/architecture/adr/0023-onda5-recurring-group-booking-waitlist.md"
last_updated: "2026-08-05"
---

# 041 — AppCliente runtime sob feature flag

Backlog decorrente de DEC-56. A fatia 039 entrega somente o contrato de banco para identidade, inbox, aceite e outbox de oferta da waitlist. Esta issue não autoriza ativação nem promove a Onda 5.

Ao iniciar uma nova Onda, implementar sob `organizations.settings.app_cliente_waitlist_enabled`, com default `false` e guard real em toda rota/tela/worker client-facing. A flag só pode ser ativada depois de existirem AppCliente, login por magic link, vínculo administrativo seguro de conta a `clients.id`, rotas HTTP com JWT, consumidor idempotente do outbox FCM, credenciais Firebase fora do repositório, deep links e testes de integração.

Aceite: a flag é validada por migration/pre-flight; desligada bloqueia API, inbox, cadastro de dispositivo e consumo do outbox; ligada após autorização permite exclusivamente o tenant habilitado; worker não envia antes de commit, não vaza token entre clientes/tenants e é idempotente; rollback operacional é desabilitar a flag, sem apagar ofertas ou eventos.
