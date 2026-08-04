---
title: "Onda 5 — aceitação transacional da waitlist"
status: "DRAFT"
stage: "ISSUE"
governance_ref: ["DEC-51", "ADR-0023"]
upstream_doc: "docs/waves/onda-5-recurring-group-waitlist/KORTEXOS_5_1_2_BLUEPRINT_ONDA_5.md"
last_updated: "2026-08-04"
---

# 035 — token, CAS e confirmação

Implementar aceitação/recusa/expiração de oferta. Aceitação exige `offer_id`, token de uso único e sessão/OTP; usa CAS em `status = 'OFFERED'`, chama `create_appointment` e grava vitória em transação única. As ofertas concorrentes viram `SUPERSEDED`; expiração/recusa retorna a entrada para `ACTIVE`; `BOOKED` não reentra por cancelamento posterior.

Aceite: testes de concorrência provam um único vencedor, replay do token falha, rollback não deixa appointment órfão, oferta expirada não reserva slot e RLS não permite aceitar oferta de outro tenant.
