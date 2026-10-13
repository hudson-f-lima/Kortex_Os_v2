---
title: "Onda 5 — verificação de slot disponível antes da oferta"
status: "IMPLEMENTADA"
stage: "ISSUE"
governance_ref: ["DEC-52", "DEC-54", "ADR-0023"]
upstream_doc: "docs/waves/onda-5-recurring-group-waitlist/KORTEXOS_5_1_2_BLUEPRINT_ONDA_5.md"
last_updated: "2026-08-06"
---

# 038 — verificação de slot disponível antes da oferta

Corretiva (DEC-54). Extrair uma verificação compartilhada de slot disponível — política, turno, elegibilidade tri-state e appointments ocupantes — e usá-la em `waitlist_matcher_run` antes de gerar cada oferta. Hoje o matcher oferta sem checar disponibilidade real, deixando toda a proteção de corrida para o momento do aceite. `create_appointment` segue como proteção transacional final; a nova verificação não a substitui, só evita ofertar o que já não está disponível.

Aceite: slot já ocupado gera zero ofertas para aquele slot; teste de concorrência entre a corrida do matcher e uma reserva simultânea não cria appointment órfão nem deixa entrada presa em `HOLDING`.
