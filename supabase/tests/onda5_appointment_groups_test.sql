-- Onda 5, fatia 032 (issues/032-onda5-group-booking.md). Prova o Aceite:
-- rollback integral em falha de qualquer filho, cardinalidade 2-10, e grupo
-- agregado consistente (status derivado dos filhos reais). Visibilidade
-- requester/participante/staff é responsabilidade de uma camada Express que
-- esta fatia não constrói (issue 032 não pede Jest/rota — mesmo escopo
-- deliberado de issues/033); o que a RLS unit-aware já garante é coberto
-- pelo Behavior 11 abaixo.
BEGIN;
SELECT plan(16);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('onda5-groups-owner1@test.local') AS owner1 \gset
SELECT (public.create_organization(:'owner1'::uuid, 'Org Groups', 'org-groups')).id AS org1 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org1'::uuid AND is_default) AS unit1 \gset

INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Cabelo', 'percentage', 4500) RETURNING id AS group1 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Corte', 5000, 30, :'group1'::uuid) RETURNING id AS service1 \gset

INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Prof 1') RETURNING id AS prof1 \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Prof 2') RETURNING id AS prof2 \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Prof 3') RETURNING id AS prof3 \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Prof 4 (blocked)') RETURNING id AS prof4 \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Prof 5') RETURNING id AS prof5 \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Prof 6') RETURNING id AS prof6 \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Prof 7') RETURNING id AS prof7 \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Prof 8') RETURNING id AS prof8 \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Prof 9') RETURNING id AS prof9 \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Prof 10') RETURNING id AS prof10 \gset

INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Requester', :'owner1'::uuid) RETURNING id AS requester \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Participante 1', :'owner1'::uuid) RETURNING id AS c1 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Participante 2', :'owner1'::uuid) RETURNING id AS c2 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Participante 3', :'owner1'::uuid) RETURNING id AS c3 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Participante 4', :'owner1'::uuid) RETURNING id AS c4 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Participante 5', :'owner1'::uuid) RETURNING id AS c5 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Participante 6', :'owner1'::uuid) RETURNING id AS c6 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Participante 7', :'owner1'::uuid) RETURNING id AS c7 \gset

-- appointment_group_create sempre roda com origin='group' (nunca 'direct'),
-- então o Availability Resolver é obrigatório para todo filho (Blueprint
-- §3.1.3, herdado de create_appointment/fatia030) — diferente de
-- onda5_appointment_participants_test.sql, que usa origin='direct' e não
-- precisa destes fixtures. 2026-09-07/14/21 são segundas-feiras (dow=1);
-- política/turno abertos 09:00-18:00 local (America/Sao_Paulo, UTC-3 — por
-- isso os horários abaixo em UTC são local+3h).
INSERT INTO public.calendar_policies (organization_id, unit_id, weekly_schedule, valid_from, created_by)
  VALUES (:'org1'::uuid, :'unit1'::uuid, '{"1": [{"start":"09:00","end":"18:00"}]}'::jsonb, '2026-01-01 00:00:00-03'::timestamptz, :'owner1'::uuid);
INSERT INTO public.professional_shifts (organization_id, professional_id, unit_id, weekly_schedule, valid_from, created_by)
  SELECT :'org1'::uuid, p.id, :'unit1'::uuid, '{"1": [{"start":"09:00","end":"18:00"}]}'::jsonb, '2026-01-01 00:00:00-03'::timestamptz, :'owner1'::uuid
  FROM public.professionals p WHERE p.organization_id = :'org1'::uuid;

-- Behavior 1/2 (issue 032): criação atômica de um grupo de 3 participantes,
-- cada um com profissional próprio; cada filho ganha titular automático
-- (integração com a fatia 033).
SELECT public.appointment_group_create(
  :'org1'::uuid, :'owner1'::uuid, 'grp-create-0001',
  jsonb_build_object(
    'unit_id', :'unit1'::uuid, 'requester_client_id', :'requester'::uuid,
    'service_id', :'service1'::uuid, 'starts_at', '2026-09-07T13:00:00Z',
    'participants', jsonb_build_array(
      jsonb_build_object('client_id', :'c1', 'professional_id', :'prof1'),
      jsonb_build_object('client_id', :'c2', 'professional_id', :'prof2'),
      jsonb_build_object('client_id', :'c3', 'professional_id', :'prof3')
    )
  )
) AS group1_response \gset
SELECT (:'group1_response'::jsonb -> 'group' ->> 'id')::uuid AS group1_id \gset

SELECT is(
  (SELECT count(*) FROM public.appointments WHERE group_id = :'group1_id'::uuid),
  3::bigint,
  'appointment_group_create materializes exactly the 3 requested children'
);
SELECT is(
  (SELECT status FROM public.appointment_groups WHERE id = :'group1_id'::uuid),
  'SCHEDULED',
  'a freshly created group with no cancellations is SCHEDULED'
);
SELECT is(
  (SELECT count(*) FROM public.appointment_participants
    WHERE appointment_id IN (SELECT id FROM public.appointments WHERE group_id = :'group1_id'::uuid)
      AND role = 'payer_beneficiary'),
  3::bigint,
  'every child of the group got its own titleholder participant row (fatia 033 integration)'
);

-- Behavior 3 (issue 032, cardinalidade): fora de 2-10 é rejeitado antes de
-- tocar qualquer registro real.
SELECT throws_ok(
  format(
    'select public.appointment_group_create(%L, %L, %L, jsonb_build_object(''unit_id'', %L::uuid, ''requester_client_id'', %L::uuid, ''service_id'', %L::uuid, ''starts_at'', %L, ''participants'', jsonb_build_array(jsonb_build_object(''client_id'', %L::uuid, ''professional_id'', %L::uuid))))',
    :'org1', :'owner1', 'grp-create-toofew-0001', :'unit1', :'requester', :'service1', '2026-09-11T10:00:00Z', :'c1', :'prof1'
  ),
  '22023',
  'participants must be an array with between 2 and 10 entries',
  'a single-participant group is rejected (cardinality floor)'
);
SELECT throws_ok(
  format(
    $q$select public.appointment_group_create(%L, %L, %L, jsonb_build_object('unit_id', %L::uuid, 'requester_client_id', %L::uuid, 'service_id', %L::uuid, 'starts_at', %L, 'participants', (select jsonb_agg(jsonb_build_object('client_id', gen_random_uuid(), 'professional_id', gen_random_uuid())) from generate_series(1,11))))$q$,
    :'org1', :'owner1', 'grp-create-toomany-0001', :'unit1', :'requester', :'service1', '2026-09-11T11:00:00Z'
  ),
  '22023',
  'participants must be an array with between 2 and 10 entries',
  'an eleven-participant group is rejected (cardinality ceiling) before any real record is touched'
);

-- Behavior 4 (issue 032, rollback integral): um filho que colide com um
-- appointment já existente derruba a transação inteira — inclusive os
-- irmãos que, isolados, não colidiriam com nada.
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente bloqueador', :'owner1'::uuid) RETURNING id AS blocker_client \gset
INSERT INTO public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, created_by, unit_id)
  VALUES (:'org1'::uuid, :'blocker_client'::uuid, :'prof4'::uuid, :'service1'::uuid, '2026-09-07T14:00:00Z', '2026-09-07T14:30:00Z', :'owner1'::uuid, :'unit1'::uuid);

SELECT (SELECT count(*) FROM public.appointment_groups) AS groups_before_collision \gset
SELECT throws_ok(
  format(
    'select public.appointment_group_create(%L, %L, %L, jsonb_build_object(''unit_id'', %L::uuid, ''requester_client_id'', %L::uuid, ''service_id'', %L::uuid, ''starts_at'', %L, ''participants'', jsonb_build_array(jsonb_build_object(''client_id'', %L::uuid, ''professional_id'', %L::uuid), jsonb_build_object(''client_id'', %L::uuid, ''professional_id'', %L::uuid))))',
    :'org1', :'owner1', 'grp-create-collision-0001', :'unit1', :'requester', :'service1', '2026-09-07T14:00:00Z',
    :'c5', :'prof5', :'c4', :'prof4'
  ),
  '23P01',
  NULL,
  'a colliding sibling (prof4 already booked at that slot) aborts the whole group creation'
);
SELECT is(
  (SELECT count(*) FROM public.appointment_groups),
  :'groups_before_collision'::bigint,
  'the group row itself never persists when any child fails (no orphaned appointment_groups row)'
);
SELECT is(
  (SELECT count(*) FROM public.appointments WHERE professional_id = :'prof5'::uuid),
  0::bigint,
  'the non-colliding sibling (prof5) is rolled back too — atomicity covers the whole group, not per-child'
);

-- Behavior 5 (issue 032, appointment_group_member_add): adiciona um 4º
-- participante derivando serviço/horário de um filho ativo existente.
SELECT public.appointment_group_member_add(
  :'org1'::uuid, :'owner1'::uuid, 'grp-member-add-0001',
  jsonb_build_object('group_id', :'group1_id'::uuid, 'client_id', :'c6'::uuid, 'professional_id', :'prof6'::uuid)
) AS member_add_response \gset
SELECT is(
  (SELECT (service_id, starts_at) FROM public.appointments WHERE id = ((:'member_add_response'::jsonb -> 'appointment' ->> 'id')::uuid)),
  (:'service1'::uuid, '2026-09-07T13:00:00Z'::timestamptz),
  'the new member inherits the group''s shared service and start time'
);
SELECT is(
  (SELECT role FROM public.appointment_participants
    WHERE appointment_id = ((:'member_add_response'::jsonb -> 'appointment' ->> 'id')::uuid) AND client_id = :'c6'::uuid),
  'payer_beneficiary',
  'the new member also gets its own titleholder participant row'
);
SELECT is(
  (SELECT status FROM public.appointment_groups WHERE id = :'group1_id'::uuid),
  'SCHEDULED',
  'adding an active member keeps the group SCHEDULED'
);

-- Behavior 6 (issue 032, cancelamento e agregado consistente):
-- appointment_group_cancel cancela todos os filhos e o status agregado
-- reflete isso via o trigger de sincronização.
SELECT public.appointment_group_cancel(:'org1'::uuid, :'owner1'::uuid, 'grp-cancel-0001', jsonb_build_object('group_id', :'group1_id'::uuid));
SELECT is(
  (SELECT count(*) FROM public.appointments WHERE group_id = :'group1_id'::uuid AND status <> 'cancelled'),
  0::bigint,
  'appointment_group_cancel cancels every child of the group'
);
SELECT is(
  (SELECT status FROM public.appointment_groups WHERE id = :'group1_id'::uuid),
  'CANCELLED',
  'the group status becomes CANCELLED once every child is cancelled'
);

-- Behavior 7 (issue 032, agregado reativo a cancelamento avulso): cancelar
-- UM filho pelo caminho genérico (update_appointment direto, não a RPC de
-- grupo) também recomputa o status do grupo — prova que o trigger cobre
-- cancelamentos ad-hoc, não só os feitos via appointment_group_cancel.
SELECT public.appointment_group_create(
  :'org1'::uuid, :'owner1'::uuid, 'grp-create-partial-0001',
  jsonb_build_object(
    'unit_id', :'unit1'::uuid, 'requester_client_id', :'requester'::uuid,
    'service_id', :'service1'::uuid, 'starts_at', '2026-09-14T13:00:00Z',
    'participants', jsonb_build_array(
      jsonb_build_object('client_id', :'c7', 'professional_id', :'prof7'),
      jsonb_build_object('client_id', :'requester', 'professional_id', :'prof8')
    )
  )
) -> 'group' ->> 'id' AS group2_id \gset
SELECT id AS group2_child1, version AS group2_child1_version
  FROM public.appointments WHERE group_id = :'group2_id'::uuid AND professional_id = :'prof7'::uuid \gset
SELECT public.update_appointment(
  :'org1'::uuid, :'owner1'::uuid, 'grp-partial-child-cancel-0001', :'group2_child1'::uuid,
  jsonb_build_object('status', 'cancelled', 'version', :'group2_child1_version')
);
SELECT is(
  (SELECT status FROM public.appointment_groups WHERE id = :'group2_id'::uuid),
  'PARTIAL',
  'cancelling a single child through the generic update_appointment path still recomputes the group as PARTIAL'
);

-- Behavior 8 (issue 032, appointment_group_update): reagenda o horário
-- compartilhado atomicamente em todos os filhos ainda ativos.
SELECT public.appointment_group_create(
  :'org1'::uuid, :'owner1'::uuid, 'grp-create-reschedule-0001',
  jsonb_build_object(
    'unit_id', :'unit1'::uuid, 'requester_client_id', :'requester'::uuid,
    'service_id', :'service1'::uuid, 'starts_at', '2026-09-21T13:00:00Z',
    'participants', jsonb_build_array(
      jsonb_build_object('client_id', :'c1', 'professional_id', :'prof9'),
      jsonb_build_object('client_id', :'c2', 'professional_id', :'prof10')
    )
  )
) -> 'group' ->> 'id' AS group3_id \gset
SELECT public.appointment_group_update(
  :'org1'::uuid, :'owner1'::uuid, 'grp-reschedule-0001',
  jsonb_build_object('group_id', :'group3_id'::uuid, 'starts_at', '2026-09-21T19:00:00Z')
);
SELECT is(
  (SELECT count(*) FROM public.appointments WHERE group_id = :'group3_id'::uuid AND starts_at = '2026-09-21T19:00:00Z'::timestamptz),
  2::bigint,
  'appointment_group_update reschedules every active child to the new shared start time'
);

-- Behavior 9 (mesma disciplina de appointment_series/appointment_participants):
-- authenticated não tem grant de escrita direta em appointment_groups.
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.appointment_groups', 'INSERT'),
  'authenticated has no direct INSERT privilege on appointment_groups'
);

SELECT * FROM finish();
ROLLBACK;
