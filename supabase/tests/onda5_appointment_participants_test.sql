-- Onda 5, fatia 033 (issues/033-onda5-participants.md). Prova as 5 linhas do
-- Aceite: todo appointment possui titular, nenhum titular é duplicado, FKs
-- não cruzam tenant/unidade, backfill é seguro em retry e update_appointment
-- rejeita transferência implícita — sem quebrar o replan explícito (Onda 1).
BEGIN;
SELECT plan(15);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('onda5-participants-owner1@test.local') AS owner1 \gset
SELECT (public.create_organization(:'owner1'::uuid, 'Org Participants', 'org-participants')).id AS org1 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org1'::uuid AND is_default) AS unit1 \gset

INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Cabelo', 'percentage', 4500) RETURNING id AS group1 \gset
-- deposit_mechanic='hold' porque o Behavior 8 exercita appointment_replan_with_hold,
-- que exige um deposit_hold ativo (Onda 1 remediação, fatia 3b).
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id, deposit_mechanic, deposit_type, deposit_value)
  VALUES (:'org1'::uuid, 'Corte', 5000, 30, :'group1'::uuid, 'hold', 'fixed', 2000) RETURNING id AS service1 \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Ana') RETURNING id AS prof1 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Um', :'owner1'::uuid) RETURNING id AS client1 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Dois (transfer)', :'owner1'::uuid) RETURNING id AS client2 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Três (companion)', :'owner1'::uuid) RETURNING id AS client3 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Legado', :'owner1'::uuid) RETURNING id AS client_legacy \gset

-- Segundo tenant, só para o Behavior 7 (isolamento de tenant via FK).
SELECT pg_temp.mk_user('onda5-participants-owner2@test.local') AS owner2 \gset
SELECT (public.create_organization(:'owner2'::uuid, 'Org Participants Two', 'org-participants-2')).id AS org2 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org2'::uuid, 'Cliente Org2', :'owner2'::uuid) RETURNING id AS client_org2 \gset

-- Behavior 1/2 (issue 033): create_appointment materializa o appointment e o
-- trigger AFTER INSERT cria a linha de titular automaticamente, sem
-- duplicata.
SELECT (public.create_appointment(
  :'org1'::uuid, :'owner1'::uuid, 'ptp-appt1-0001',
  jsonb_build_object(
    'client_id', :'client1'::uuid, 'professional_id', :'prof1'::uuid, 'service_id', :'service1'::uuid,
    'starts_at', '2026-09-01T13:00:00Z'
  )
) -> 'appointment' ->> 'id')::uuid AS appt1 \gset

SELECT is(
  (SELECT count(*) FROM public.appointment_participants WHERE appointment_id = :'appt1'::uuid),
  1::bigint,
  'every appointment gets exactly one participant row on creation (titular)'
);
SELECT is(
  (SELECT (client_id, role) FROM public.appointment_participants WHERE appointment_id = :'appt1'::uuid),
  (:'client1'::uuid, 'payer_beneficiary'::text),
  'the titleholder row mirrors appointments.client_id with role payer_beneficiary'
);

-- Behavior 3 (issue 033): update_appointment rejeita transferência implícita
-- de titular fora do comando explícito de replan.
SELECT throws_ok(
  format(
    'select public.update_appointment(%L, %L, %L, %L, jsonb_build_object(''client_id'', %L::uuid, ''version'', 1))',
    :'org1', :'owner1', 'ptp-update-immutable-0001', :'appt1', :'client2'
  ),
  'P0022', 'appointment titleholder (client_id) is immutable outside the explicit replan command',
  'update_appointment rejects an implicit client_id transfer'
);
SELECT is(
  (SELECT public.update_appointment(
    :'org1'::uuid, :'owner1'::uuid, 'ptp-update-status-0001', :'appt1'::uuid,
    jsonb_build_object('status', 'confirmed', 'version', 1)
  ) ->> 'status'),
  'applied',
  'update_appointment still applies non-client_id fields normally'
);

-- Behavior 4 (issue 033): backfill é seguro em retry. Simula um appointment
-- "legado" inserido com o trigger desligado (representando dado anterior a
-- esta fatia), roda a mesma instrução de backfill da migration duas vezes e
-- prova que a segunda execução não duplica.
ALTER TABLE public.appointments DISABLE TRIGGER appointments_create_titleholder_participant;
INSERT INTO public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, created_by, unit_id)
  VALUES (:'org1'::uuid, :'client_legacy'::uuid, :'prof1'::uuid, :'service1'::uuid, '2026-09-02T13:00:00Z', '2026-09-02T13:30:00Z', :'owner1'::uuid, :'unit1'::uuid)
  RETURNING id AS legacy_appt \gset
ALTER TABLE public.appointments ENABLE TRIGGER appointments_create_titleholder_participant;

SELECT is(
  (SELECT count(*) FROM public.appointment_participants WHERE appointment_id = :'legacy_appt'::uuid),
  0::bigint,
  'a pre-fatia-033 appointment starts with no participant row (trigger was off)'
);

INSERT INTO public.appointment_participants(organization_id, unit_id, appointment_id, client_id, role)
SELECT a.organization_id, a.unit_id, a.id, a.client_id, 'payer_beneficiary'
FROM public.appointments a
WHERE not exists (
  SELECT 1 FROM public.appointment_participants ap
  WHERE ap.organization_id = a.organization_id AND ap.appointment_id = a.id AND ap.client_id = a.client_id
)
ON CONFLICT (organization_id, appointment_id, client_id) DO NOTHING;

SELECT is(
  (SELECT count(*) FROM public.appointment_participants WHERE appointment_id = :'legacy_appt'::uuid),
  1::bigint,
  'running the backfill once gives the legacy appointment its titleholder row'
);

INSERT INTO public.appointment_participants(organization_id, unit_id, appointment_id, client_id, role)
SELECT a.organization_id, a.unit_id, a.id, a.client_id, 'payer_beneficiary'
FROM public.appointments a
WHERE not exists (
  SELECT 1 FROM public.appointment_participants ap
  WHERE ap.organization_id = a.organization_id AND ap.appointment_id = a.id AND ap.client_id = a.client_id
)
ON CONFLICT (organization_id, appointment_id, client_id) DO NOTHING;

SELECT is(
  (SELECT count(*) FROM public.appointment_participants WHERE appointment_id = :'legacy_appt'::uuid),
  1::bigint,
  'retrying the backfill is a no-op — no duplicate titleholder row'
);

-- Behavior 5/6 (issue 033): o único comando aprovado de transferência
-- (appointment_replan_with_hold) continua funcionando e a linha de titular
-- em appointment_participants migra junto, na mesma transação.
SELECT (public.create_appointment(
  :'org1'::uuid, :'owner1'::uuid, 'ptp-appt2-0001',
  jsonb_build_object(
    'client_id', :'client1'::uuid, 'professional_id', :'prof1'::uuid, 'service_id', :'service1'::uuid,
    'starts_at', '2026-09-03T13:00:00Z'
  )
) -> 'appointment' ->> 'id')::uuid AS appt2 \gset
SELECT public.deposit_hold_create(:'org1'::uuid, :'owner1'::uuid, :'appt2'::uuid);

SELECT public.appointment_replan_with_hold(
  :'org1'::uuid, :'owner1'::uuid, 'ptp-replan-0001', :'appt2'::uuid,
  jsonb_build_object('client_id', :'client2', 'version', 1)
) AS replan_response \gset

SELECT is(
  (SELECT count(*) FROM public.appointment_participants WHERE appointment_id = :'appt2'::uuid AND client_id = :'client1'::uuid),
  0::bigint,
  'replan removes the former titleholder participant row'
);
SELECT is(
  (SELECT count(*) FROM public.appointment_participants WHERE appointment_id = :'appt2'::uuid),
  1::bigint,
  'replan leaves exactly one participant row — the new titleholder, no duplicate'
);
SELECT is(
  (SELECT (client_id, role) FROM public.appointment_participants WHERE appointment_id = :'appt2'::uuid),
  (:'client2'::uuid, 'payer_beneficiary'::text),
  'the surviving participant row is the new client as payer_beneficiary'
);

-- Behavior 7 (issue 033, RPC de participante): adiciona um acompanhante
-- não-titular e prova que a mesma chave idempotente não duplica.
SELECT public.appointment_participant_add(
  :'org1'::uuid, :'owner1'::uuid, 'ptp-participant-add-0001',
  jsonb_build_object('appointment_id', :'appt1'::uuid, 'client_id', :'client3'::uuid, 'role', 'beneficiary')
) AS participant_add_response \gset
SELECT is(
  (SELECT role FROM public.appointment_participants WHERE appointment_id = :'appt1'::uuid AND client_id = :'client3'::uuid),
  'beneficiary',
  'appointment_participant_add creates a non-titleholder participant with the requested role'
);
SELECT public.appointment_participant_add(
  :'org1'::uuid, :'owner1'::uuid, 'ptp-participant-add-0001',
  jsonb_build_object('appointment_id', :'appt1'::uuid, 'client_id', :'client3'::uuid, 'role', 'beneficiary')
);
SELECT is(
  (SELECT count(*) FROM public.appointment_participants WHERE appointment_id = :'appt1'::uuid),
  2::bigint,
  'retrying appointment_participant_add with the same idempotency key does not duplicate the participant'
);

-- Behavior 8 (issue 033): a RPC nunca rebaixa a role do titular, mesmo que
-- role diferente seja explicitamente pedida para o client_id do titular.
SELECT public.appointment_participant_add(
  :'org1'::uuid, :'owner1'::uuid, 'ptp-participant-add-0002',
  jsonb_build_object('appointment_id', :'appt1'::uuid, 'client_id', :'client1'::uuid, 'role', 'beneficiary')
);
SELECT is(
  (SELECT role FROM public.appointment_participants WHERE appointment_id = :'appt1'::uuid AND client_id = :'client1'::uuid),
  'payer_beneficiary',
  'appointment_participant_add never demotes the titleholder row away from payer_beneficiary'
);

-- Behavior 9 (issue 033, "FKs não cruzam tenant"): um client de outra
-- organização nunca compõe uma linha de participante de um appointment
-- deste tenant, mesmo com organization_id do appointment certo no restante
-- da linha.
SELECT throws_ok(
  format(
    'insert into public.appointment_participants(organization_id, unit_id, appointment_id, client_id, role) values (%L, %L, %L, %L, %L)',
    :'org1', :'unit1', :'appt1', :'client_org2', 'beneficiary'
  ),
  '23503',
  NULL,
  'a participant row cannot reference a client from another tenant'
);

-- Behavior 10 (issue 033, mesma disciplina de appointment_series):
-- authenticated não tem grant de escrita direta — só o trigger de titular
-- (security definer) e as RPCs.
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.appointment_participants', 'INSERT'),
  'authenticated has no direct INSERT privilege on appointment_participants'
);

SELECT * FROM finish();
ROLLBACK;
