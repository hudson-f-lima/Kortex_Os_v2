---
title: "Onda 5 — guard unit-aware nas RPCs de escrita"
status: "IMPLEMENTADA"
stage: "ISSUE"
governance_ref: ["DEC-52", "DEC-54", "ADR-0023"]
upstream_doc: "docs/waves/onda-5-recurring-group-waitlist/KORTEXOS_5_1_2_BLUEPRINT_ONDA_5.md"
last_updated: "2026-08-06"
---

# 037 — guard unit-aware nas RPCs de escrita

Corretiva (DEC-54). Criar um guard compartilhado que verifica a `unit_id` do objeto-alvo contra a unidade da membership do actor (não só pertencimento à organização) e aplicá-lo a todas as RPCs de escrita de série, grupo e waitlist — hoje elas checam `is_member`/`organization_id`, mas não a unidade, permitindo que uma membership vinculada a uma única unidade opere objeto de outra unidade da mesma organização.

Aceite: reception vinculada só à unidade A recebe `403`/`42501` ao tentar criar, editar, cancelar ou aceitar oferta de objeto cuja `unit_id` é da unidade B da mesma organização; owner/admin/manager org-wide continuam operando qualquer unidade sem regressão.
