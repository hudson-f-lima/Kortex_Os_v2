-- Onda 1 remediation, fatia 1: a identidade financeira de um depósito é
-- congelada no hold; um PATCH genérico não pode redirecioná-la depois.
BEGIN;
SELECT plan(5);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('owner-identity@test.local') AS owner_id \gset
SELECT (public.create_organization(:'owner_id'::uuid, 'Org Financial Identity', 'org-financial-identity')).id AS org_id \gset

INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
VALUES (:'org_id'::uuid, 'Grupo', 'percentage', 1000) RETURNING id AS group_id \gset
INSERT INTO public.services (
  organization_id, name, price_cents, duration_minutes, service_group_id,
  deposit_mechanic, deposit_type, deposit_value
) VALUES (
  :'org_id'::uuid, 'Serviço com depósito', 10000, 30, :'group_id'::uuid,
  'hold', 'fixed', 2000
) RETURNING id AS service_id \gset
INSERT INTO public.professionals (organization_id, name)
VALUES (:'org_id'::uuid, 'Profissional') RETURNING id AS professional_id \gset
INSERT INTO public.clients (organization_id, name, created_by)
VALUES (:'org_id'::uuid, 'Cliente original', :'owner_id'::uuid) RETURNING id AS client_a \gset
INSERT INTO public.clients (organization_id, name, created_by)
VALUES (:'org_id'::uuid, 'Cliente substituto', :'owner_id'::uuid) RETURNING id AS client_b \gset
INSERT INTO public.appointments (
  organization_id, client_id, professional_id, service_id, starts_at, ends_at, created_by
) VALUES (
  :'org_id'::uuid, :'client_a'::uuid, :'professional_id'::uuid, :'service_id'::uuid,
  '2026-08-10 10:00+00', '2026-08-10 10:30+00', :'owner_id'::uuid
) RETURNING id AS appointment_id \gset

SELECT public.deposit_hold_create(:'org_id'::uuid, :'owner_id'::uuid, :'appointment_id'::uuid);

SELECT is(
  (SELECT client_id FROM public.deposit_holds WHERE appointment_id = :'appointment_id'::uuid),
  :'client_a'::uuid,
  'deposit_holds snapshots the original client identity'
);
SELECT is(
  (SELECT service_id FROM public.deposit_holds WHERE appointment_id = :'appointment_id'::uuid),
  :'service_id'::uuid,
  'deposit_holds snapshots the original service identity'
);
SELECT is(
  (SELECT professional_id FROM public.deposit_holds WHERE appointment_id = :'appointment_id'::uuid),
  :'professional_id'::uuid,
  'deposit_holds snapshots the original professional identity'
);

-- Onda 5, fatia 033: "titular imutável" endureceu update_appointment para
-- rejeitar QUALQUER client_id fora do escape hatch de replan (P0022),
-- supersedendo em generalidade o guard P0007 desta fatia (Onda 1) para o
-- caminho genérico especificamente — P0007 seguia sendo levantado só quando
-- havia hold ativo; agora nenhuma mudança de client_id passa por
-- update_appointment sem a flag interna, hold ativo ou não. O guard
-- original de identidade financeira (trigger
-- appointments_active_hold_identity_guard) continua existindo e protegendo
-- outros caminhos; só não é mais alcançado por ESTE, porque P0022 barra
-- primeiro.
SELECT throws_ok(
  format(
    $sql$select public.update_appointment(%L, %L, 'change-client-after-hold-001', %L, jsonb_build_object('client_id', %L, 'version', 1))$sql$,
    :'org_id', :'owner_id', :'appointment_id', :'client_b'
  ),
  'P0022',
  NULL,
  'a generic appointment update cannot change client_id while an active hold exists (superseded by the broader titleholder-immutable guard, fatia 033)'
);

SELECT is(
  (SELECT client_id FROM public.appointments WHERE id = :'appointment_id'::uuid),
  :'client_a'::uuid,
  'the rejected mutation leaves the appointment and financial identity intact'
);

SELECT * FROM finish();
ROLLBACK;
