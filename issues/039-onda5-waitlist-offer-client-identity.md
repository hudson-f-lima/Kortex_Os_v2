---
title: "Onda 5 — identidade client-facing da oferta de waitlist"
status: "IMPLEMENTADA"
stage: "ISSUE"
governance_ref: ["DEC-52", "DEC-54", "DEC-55", "ADR-0023"]
upstream_doc: "docs/waves/onda-5-recurring-group-waitlist/KORTEXOS_5_1_2_BLUEPRINT_ONDA_5.md"
last_updated: "2026-08-06"
---

# 039 — AppCliente autenticado e push da oferta de waitlist

## Implementação local (2026-08-05)

Entregues a migration `20260805220000_onda5_fatia039_client_identity_push_outbox.sql` e o pgTAP `onda5_waitlist_client_identity_test.sql`. `client_app_identities` vincula unicamente `organization_id` + `auth.users.id` a `clients.id`; `client_push_devices` fica protegido por RLS e as RPCs derivam `auth.uid()` em vez de aceitar cliente pelo body. `waitlist_offer_accept_client` valida a identidade junto da oferta e do token antes de reutilizar `create_appointment`; `appointments.client_booking_user_id` registra o usuário AppCliente sem violar o FK histórico de `created_by` para membership operacional.

O matcher cria itens no outbox privado somente para dispositivos do cliente dono da oferta, dentro da transação que cria a oferta. Consumidores FCM só podem observá-los após commit. `client_waitlist_offer_inbox` é o fallback autenticado: lista ofertas ainda abertas e reemite a capacidade opaca sem persistir token legível. Não há AppCliente, credenciais Firebase ou worker FCM nesta base; a entrega efetiva é dependência explícita da infraestrutura do aplicativo, não uma simulação de push.

Evidência: RED confirmado por ausência dos objetos; GREEN 12/12 no pgTAP da fatia; regressão da Onda 5 13/13 arquivos pgTAP em reset limpo local.

Corretiva (DEC-54, refinada por DEC-55). Implementar a identidade de cliente pela sessão autenticada do AppCliente e a entrega de oferta por push FCM. A escolha OTP de DEC-54 é parcialmente superada: não há OTP, SMS nem `client_id` confiado pelo body. O backend deriva `auth.uid()` do JWT, resolve no servidor um único vínculo tenant-safe para `clients.id` e exige que ele corresponda ao `waitlist_entry.client_id`. Posse do token deixa de ser suficiente sozinha; o token opaco de uso único permanece obrigatório como capacidade complementar do deep link.

Entrega: após a oferta ser confirmada em commit, registrar/enfileirar uma notificação FCM para os dispositivos que o próprio cliente autenticado associou à sua conta. O deep link abre a oferta no AppCliente; a caixa de entrada do app lista a oferta enquanto o TTL estiver válido, pois push não é garantia de entrega. Falha ou ausência de token de dispositivo não desfaz a oferta nem reduz as garantias da aceitação.

Aceite: cliente sem JWT falha; JWT sem vínculo com cliente falha; JWT vinculado a outro cliente falha mesmo com token válido; JWT do mesmo cliente com token válido aceita uma única vez, mantendo CAS e revalidação de disponibilidade já existentes; replay falha; vínculo ou oferta cross-tenant falha; token FCM de um cliente não pode ser registrado, consultado ou usado para notificar outro cliente; push só é produzido após commit e a oferta permanece visível no app sem push. Cobrir cada comportamento por pgTAP e o contrato HTTP/AppCliente por teste de integração quando a rota existir.
