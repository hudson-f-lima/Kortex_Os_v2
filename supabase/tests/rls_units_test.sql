BEGIN;
SELECT plan(99);

-- Helpers: simulate Supabase Auth JWT context inside this transaction only.
CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

CREATE FUNCTION pg_temp.login_as(p_user_id uuid) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', p_user_id::text, true);
  SET LOCAL role authenticated;
END;
$$;

CREATE FUNCTION pg_temp.logout() RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  RESET role;
  PERFORM set_config('request.jwt.claim.sub', '', true);
END;
$$;

-- Fixtures (created as postgres/service-role-equivalent, bypassing RLS).
SELECT pg_temp.mk_user('owner1@test.local') AS owner1 \gset
SELECT pg_temp.mk_user('reception1@test.local') AS reception1 \gset
SELECT pg_temp.mk_user('manager1@test.local') AS manager1 \gset
SELECT pg_temp.mk_user('professional1@test.local') AS professional_user1 \gset
SELECT pg_temp.mk_user('owner2@test.local') AS owner2 \gset
SELECT pg_temp.mk_user('outsider@test.local') AS outsider \gset

SELECT (public.create_organization(:'owner1'::uuid, 'Org One', 'org-one')).id AS org1 \gset
SELECT (public.create_organization(:'owner2'::uuid, 'Org Two', 'org-two')).id AS org2 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org1'::uuid AND is_default) AS unit1 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org2'::uuid AND is_default) AS unit2 \gset
INSERT INTO public.memberships (organization_id, user_id, role, unit_id)
VALUES
  (:'org1'::uuid, :'reception1'::uuid, 'reception', :'unit1'::uuid),
  (:'org1'::uuid, :'manager1'::uuid, 'manager', null),
  (:'org1'::uuid, :'professional_user1'::uuid, 'professional', :'unit1'::uuid);

INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Profissional Um') RETURNING id AS professional1 \gset
INSERT INTO public.professionals (organization_id, user_id, name)
  VALUES (:'org1'::uuid, :'professional_user1'::uuid, 'Profissional Autenticado')
  RETURNING id AS authenticated_professional1 \gset
INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Grupo Um', 'percentage', 1000) RETURNING id AS group1 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Corte', 5000, 30, :'group1'::uuid) RETURNING id AS service1 \gset
INSERT INTO public.clients (organization_id, name, created_by)
  VALUES (:'org1'::uuid, 'Cliente Um', :'owner1'::uuid)
  RETURNING id AS client1 \gset

INSERT INTO public.professionals (organization_id, name)
  VALUES (:'org1'::uuid, 'Profissional Sem Vinculo Ativo')
  RETURNING id AS professional_without_active_unit \gset
UPDATE public.professional_units
SET active = false
WHERE organization_id = :'org1'::uuid
  AND professional_id = :'professional_without_active_unit'::uuid
  AND unit_id = :'unit1'::uuid;

-- Legacy compatibility is intentionally disabled after the canonical command.
-- The legacy RPC cannot express unit scope and must have no executable path.
SELECT ok(
  NOT has_function_privilege(
    'service_role',
    'public.membership_set(uuid,uuid,uuid,text,boolean)',
    'EXECUTE'
  ),
  'legacy membership_set is not executable by service_role'
);

-- === Layer 1: grants — no direct table privilege for anon/authenticated ===
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.units', 'SELECT'),
  'authenticated has no direct SELECT grant on units'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.unit_access_audit_events', 'SELECT'),
  'authenticated has no direct SELECT grant on unit_access_audit_events'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.unit_access_audit_events', 'INSERT'),
  'authenticated has no direct INSERT grant on unit_access_audit_events'
);

-- === Layer 2: RLS policies (temporarily grant table privileges within this
-- transaction only, to prove policies isolate tenants even if grants ever change) ===
GRANT SELECT, INSERT ON public.units TO authenticated;
GRANT SELECT, INSERT ON public.professional_units TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.unit_access_audit_events TO authenticated;

SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.units WHERE id = :'unit1'::uuid),
  'owner1 sees org1''s default unit'
);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.units WHERE id = :'unit2'::uuid),
  'owner1 cannot see org2''s unit (cross-tenant select denied)'
);
SELECT lives_ok(
  format('insert into public.units (organization_id, name, timezone) values (%L, %L, %L)', :'org1', 'Filial Centro', 'America/Sao_Paulo'),
  'owner1 (role owner) can insert a second unit in org1'
);
SELECT throws_ok(
  format('insert into public.unit_access_audit_events (organization_id, event_type, actor_kind, actor_user_id) values (%L, %L, %L, %L)', :'org1', 'unit_created', 'user', :'owner1'),
  '42501',
  NULL,
  'owner1 cannot insert directly into unit_access_audit_events (no RLS insert policy — append-only via security definer functions only)'
);
WITH updated AS (
  UPDATE public.unit_access_audit_events
  SET after_state = '{"tampered":true}'::jsonb
  WHERE organization_id = :'org1'::uuid
  RETURNING 1
)
SELECT is(
  (SELECT count(*)::integer FROM updated),
  0,
  'owner1 cannot update append-only unit_access_audit_events'
);
WITH deleted AS (
  DELETE FROM public.unit_access_audit_events
  WHERE organization_id = :'org1'::uuid
  RETURNING 1
)
SELECT is(
  (SELECT count(*)::integer FROM deleted),
  0,
  'owner1 cannot delete append-only unit_access_audit_events'
);

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.units WHERE id = :'unit1'::uuid),
  'reception1 (any active member) can still see org1''s unit'
);
SELECT ok(
  NOT EXISTS(
    SELECT 1
    FROM public.units
    WHERE organization_id = :'org1'::uuid
      AND name = 'Filial Centro'
  ),
  'reception1 cannot see another unit in the same organization'
);
SELECT throws_ok(
  format('insert into public.units (organization_id, name, timezone) values (%L, %L, %L)', :'org1', 'Filial Indevida', 'America/Sao_Paulo'),
  '42501',
  NULL,
  'reception1 (insufficient role) cannot insert a new unit'
);

SELECT pg_temp.login_as(:'outsider'::uuid);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.units WHERE id = :'unit1'::uuid),
  'outsider (no membership) cannot see org1''s unit'
);

SELECT pg_temp.logout();
SELECT (
  SELECT id
  FROM public.units
  WHERE organization_id = :'org1'::uuid
    AND name = 'Filial Centro'
) AS unit1b \gset

-- === professional_units: every new professional is linked to the default unit ===
SELECT ok(
  EXISTS(
    SELECT 1 FROM public.professional_units
    WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid
  ),
  'a professional created after Onda 0 is automatically linked to the organization default unit'
);

-- === Default-fill trigger: new facts without unit_id resolve to the org default ===
INSERT INTO public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, created_by)
  VALUES (:'org1'::uuid, :'client1'::uuid, :'professional1'::uuid, :'service1'::uuid, now() + interval '1 day', now() + interval '1 day 30 minutes', :'owner1'::uuid)
  RETURNING id AS appointment1 \gset
SELECT is(
  (SELECT count(*)::integer FROM public.appointments WHERE organization_id = :'org1'::uuid AND unit_id IS NULL),
  0,
  'appointments inserted without an explicit unit_id are default-filled by the trigger (none left null)'
);
SELECT ok(
  (SELECT unit_id FROM public.appointments WHERE organization_id = :'org1'::uuid ORDER BY created_at DESC LIMIT 1) = :'unit1'::uuid,
  'the default-fill trigger resolves the new appointment to org1''s default unit'
);
SELECT throws_ok(
  format(
    'insert into public.appointments (organization_id, unit_id, client_id, professional_id, service_id, starts_at, ends_at, created_by) values (%L, %L, %L, %L, %L, now() + interval ''2 days'', now() + interval ''2 days 30 minutes'', %L)',
    :'org1', :'unit1', :'client1', :'professional_without_active_unit', :'service1', :'owner1'
  ),
  '23514',
  NULL,
  'an appointment rejects a professional without an active link to its unit'
);
SELECT throws_ok(
  format(
    'insert into public.appointments (organization_id, unit_id, client_id, professional_id, service_id, starts_at, ends_at, created_by) values (%L, %L, %L, %L, %L, now() + interval ''3 days'', now() + interval ''3 days 30 minutes'', %L)',
    :'org1', :'unit1b', :'client1', :'professional1', :'service1', :'owner1'
  ),
  '23514',
  NULL,
  'an appointment rejects a professional linked to another unit in the same organization'
);
SELECT throws_ok(
  format(
    'insert into public.appointments (organization_id, unit_id, client_id, professional_id, service_id, starts_at, ends_at, created_by) values (%L, %L, %L, %L, %L, now() + interval ''4 days'', now() + interval ''4 days 30 minutes'', %L)',
    :'org1', :'unit2', :'client1', :'professional1', :'service1', :'owner1'
  ),
  '23514',
  NULL,
  'an appointment rejects a unit from another organization'
);
SELECT throws_ok(
  format(
    'update public.appointments set professional_id = %L where id = %L',
    :'professional_without_active_unit', :'appointment1'
  ),
  '23514',
  NULL,
  'the existing update path rejects changing an appointment to a professional without an active unit link'
);

-- === Default-fill "from order": order_items/payments/inventory/cash inherit
-- the parent order's unit_id instead of resolving the org default directly ===
INSERT INTO public.orders (organization_id, subtotal_cents, total_cents, created_by)
  VALUES (:'org1'::uuid, 1000, 1000, :'owner1'::uuid) RETURNING id AS order1 \gset
SELECT ok(
  (SELECT unit_id FROM public.orders WHERE id = :'order1'::uuid) = :'unit1'::uuid,
  'an order inserted without unit_id resolves to org1''s default unit'
);
INSERT INTO public.payments (organization_id, order_id, method, amount_cents)
  VALUES (:'org1'::uuid, :'order1'::uuid, 'cash', 1000)
  RETURNING id AS payment1 \gset
SELECT is(
  (SELECT unit_id FROM public.payments WHERE id = :'payment1'::uuid),
  :'unit1'::uuid,
  'a payment inserted without unit_id inherits its parent order unit'
);
SELECT throws_ok(
  format(
    'insert into public.payments (organization_id, order_id, unit_id, method, amount_cents) values (%L, %L, %L, %L, %s)',
    :'org1', :'order1', :'unit1b', 'cash', 1000
  ),
  '23503',
  NULL,
  'a payment cannot diverge from its parent order unit'
);

-- === Immutability trigger: unit_id cannot change once set ===
SELECT throws_ok(
  format(
    'update public.appointments set unit_id = (select id from public.units where organization_id = %L and not is_default limit 1) where organization_id = %L',
    :'org1', :'org1'
  ),
  '23514',
  NULL,
  'unit_id on an appointment is immutable once set'
);

-- === Fact RLS: organization-wide roles keep access; unit-scoped reception
-- can only read/write facts in the membership unit. Grants are transaction
-- local and exist solely to exercise RLS in this API-only architecture. ===
INSERT INTO public.professional_units (organization_id, professional_id, unit_id, active)
  VALUES (:'org1'::uuid, :'professional1'::uuid, :'unit1b'::uuid, true);
INSERT INTO public.appointments (
  organization_id, unit_id, client_id, professional_id, service_id,
  starts_at, ends_at, created_by
)
VALUES (
  :'org1'::uuid, :'unit1b'::uuid, :'client1'::uuid, :'professional1'::uuid,
  :'service1'::uuid, now() + interval '6 days',
  now() + interval '6 days 30 minutes', :'owner1'::uuid
)
RETURNING id AS appointment_unit1b \gset
INSERT INTO public.orders (
  organization_id, unit_id, subtotal_cents, total_cents, created_by
)
VALUES (:'org1'::uuid, :'unit1b'::uuid, 2000, 2000, :'owner1'::uuid)
RETURNING id AS order_unit1b \gset
INSERT INTO public.appointments (
  organization_id, unit_id, client_id, professional_id, service_id,
  starts_at, ends_at, created_by
)
VALUES (
  :'org1'::uuid, :'unit1'::uuid, :'client1'::uuid,
  :'authenticated_professional1'::uuid, :'service1'::uuid,
  now() + interval '8 days', now() + interval '8 days 30 minutes',
  :'owner1'::uuid
)
RETURNING id AS own_professional_appointment \gset

GRANT SELECT, INSERT, UPDATE, DELETE ON public.appointments TO authenticated;
GRANT SELECT ON public.orders TO authenticated;

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.appointments WHERE id = :'appointment1'::uuid),
  'reception can read an appointment in its membership unit'
);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.appointments WHERE id = :'appointment_unit1b'::uuid),
  'reception cannot read an appointment from another unit in the same organization'
);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.orders WHERE id = :'order_unit1b'::uuid),
  'reception cannot read an order from another unit in the same organization'
);
SELECT throws_ok(
  format(
    'insert into public.appointments (organization_id, unit_id, client_id, professional_id, service_id, starts_at, ends_at, created_by) values (%L, %L, %L, %L, %L, now() + interval ''7 days'', now() + interval ''7 days 30 minutes'', %L)',
    :'org1', :'unit1b', :'client1', :'professional1', :'service1', :'reception1'
  ),
  '42501',
  NULL,
  'reception cannot create an appointment in another unit in the same organization'
);

SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.appointments WHERE id = :'appointment_unit1b'::uuid)
    AND EXISTS(SELECT 1 FROM public.orders WHERE id = :'order_unit1b'::uuid),
  'owner remains organization-wide across appointment and order units'
);

SELECT pg_temp.login_as(:'manager1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.appointments WHERE id = :'appointment_unit1b'::uuid)
    AND EXISTS(SELECT 1 FROM public.orders WHERE id = :'order_unit1b'::uuid),
  'manager remains organization-wide across appointment and order units'
);
SELECT pg_temp.logout();

SELECT pg_temp.login_as(:'professional_user1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.appointments WHERE id = :'own_professional_appointment'::uuid),
  'professional can read its own appointment in its membership unit'
);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.appointments WHERE id = :'appointment1'::uuid),
  'professional cannot read another professional appointment without schedule:view_all'
);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.appointments WHERE id = :'appointment_unit1b'::uuid),
  'professional cannot read an appointment from another unit'
);
SELECT ok(
  EXISTS(
    SELECT 1
    FROM public.professional_units
    WHERE organization_id = :'org1'::uuid
      AND unit_id = :'unit1'::uuid
      AND professional_id = :'authenticated_professional1'::uuid
  ),
  'professional can read its own professional_units link'
);
SELECT ok(
  NOT EXISTS(
    SELECT 1
    FROM public.professional_units
    WHERE organization_id = :'org1'::uuid
      AND unit_id = :'unit1'::uuid
      AND professional_id = :'professional1'::uuid
  ),
  'professional cannot read another professional link without schedule:view_all'
);
SELECT ok(
  NOT EXISTS(
    SELECT 1
    FROM public.professional_units
    WHERE organization_id = :'org1'::uuid
      AND unit_id = :'unit1b'::uuid
      AND professional_id = :'professional1'::uuid
  ),
  'professional cannot read professional links from another unit'
);
SELECT pg_temp.logout();

INSERT INTO public.membership_permissions (
  organization_id, user_id, permission_code, granted_by
)
VALUES (
  :'org1'::uuid, :'professional_user1'::uuid, 'schedule:view_all',
  :'owner1'::uuid
);

SELECT pg_temp.login_as(:'professional_user1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.appointments WHERE id = :'appointment1'::uuid),
  'schedule:view_all lets a professional read other appointments in its own unit'
);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.appointments WHERE id = :'appointment_unit1b'::uuid),
  'schedule:view_all does not cross the professional membership unit'
);
SELECT ok(
  EXISTS(
    SELECT 1
    FROM public.professional_units
    WHERE organization_id = :'org1'::uuid
      AND unit_id = :'unit1'::uuid
      AND professional_id = :'professional1'::uuid
  ),
  'schedule:view_all lets a professional read team links in its own unit'
);
SELECT ok(
  NOT EXISTS(
    SELECT 1
    FROM public.professional_units
    WHERE organization_id = :'org1'::uuid
      AND unit_id = :'unit1b'::uuid
      AND professional_id = :'professional1'::uuid
  ),
  'schedule:view_all does not expose professional links from another unit'
);
SELECT pg_temp.logout();

-- === professional_units lifecycle: deleting a professional cascades its link,
-- while a BEFORE DELETE trigger persists the topology audit first. ===
INSERT INTO public.professionals (organization_id, name)
  VALUES (:'org1'::uuid, 'Profissional Descartavel')
  RETURNING id AS disposable_professional \gset
SELECT lives_ok(
  format(
    'select public.professional_delete(%L, %L, %L)',
    :'org1', :'owner1', :'disposable_professional'
  ),
  'deleting a professional cascades its professional_units links'
);
SELECT ok(
  NOT EXISTS(
    SELECT 1
    FROM public.professional_units
    WHERE organization_id = :'org1'::uuid
      AND professional_id = :'disposable_professional'::uuid
  ),
  'the cascaded professional_units link is removed'
);
SELECT ok(
  EXISTS(
    SELECT 1
    FROM public.unit_access_audit_events
    WHERE organization_id = :'org1'::uuid
      AND professional_id = :'disposable_professional'::uuid
      AND event_type = 'professional_unit_changed'
      AND actor_kind = 'user'
      AND actor_user_id = :'owner1'::uuid
      AND before_state ->> 'active' = 'true'
      AND after_state ->> 'action' = 'deleted'
  ),
  'the cascade audit preserves the human owner who deleted the professional'
);

SELECT pg_temp.mk_user('lifecycle-delete@test.local') AS lifecycle_delete_user \gset
INSERT INTO public.memberships (organization_id, user_id, role, unit_id)
VALUES (:'org1'::uuid, :'lifecycle_delete_user'::uuid, 'professional', :'unit1'::uuid);
INSERT INTO public.professionals (organization_id, user_id, name)
VALUES (:'org1'::uuid, :'lifecycle_delete_user'::uuid, 'Profissional Lifecycle Delete')
RETURNING id AS lifecycle_delete_professional \gset
SELECT public.membership_permission_grant(
  :'org1'::uuid,
  :'owner1'::uuid,
  :'lifecycle_delete_user'::uuid,
  'clients:view_all'
);
SELECT lives_ok(
  format(
    'select public.professional_delete(%L, %L, %L)',
    :'org1', :'owner1', :'lifecycle_delete_professional'
  ),
  'professional_delete invalidates the linked professional access lifecycle'
);
SELECT ok(
  NOT (SELECT active FROM public.memberships
       WHERE organization_id = :'org1'::uuid
         AND user_id = :'lifecycle_delete_user'::uuid)
  AND NOT EXISTS (
    SELECT 1 FROM public.membership_permissions
    WHERE organization_id = :'org1'::uuid
      AND user_id = :'lifecycle_delete_user'::uuid
      AND revoked_at is null
  )
  AND EXISTS (
    SELECT 1 FROM public.unit_access_audit_events
    WHERE organization_id = :'org1'::uuid
      AND target_user_id = :'lifecycle_delete_user'::uuid
      AND event_type = 'membership_scope_changed'
      AND actor_kind = 'user'
      AND actor_user_id = :'owner1'::uuid
      AND after_state ->> 'source' = 'professional_lifecycle'
  ),
  'delete deactivates membership, revokes permissions and audits the human actor'
);

SELECT pg_temp.mk_user('lifecycle-inactive@test.local') AS lifecycle_inactive_user \gset
INSERT INTO public.memberships (organization_id, user_id, role, unit_id)
VALUES (:'org1'::uuid, :'lifecycle_inactive_user'::uuid, 'professional', :'unit1'::uuid);
INSERT INTO public.professionals (organization_id, user_id, name)
VALUES (:'org1'::uuid, :'lifecycle_inactive_user'::uuid, 'Profissional Lifecycle Inactive')
RETURNING id AS lifecycle_inactive_professional \gset
SELECT public.membership_permission_grant(
  :'org1'::uuid,
  :'owner1'::uuid,
  :'lifecycle_inactive_user'::uuid,
  'schedule:view_all'
);
SELECT lives_ok(
  format(
    'select public.professional_update(%L, %L, %L, %L::jsonb)',
    :'org1',
    :'owner1',
    :'lifecycle_inactive_professional',
    '{"active": false}'
  ),
  'deactivating a professional invalidates its access lifecycle'
);
SELECT ok(
  NOT (SELECT active FROM public.memberships
       WHERE organization_id = :'org1'::uuid
         AND user_id = :'lifecycle_inactive_user'::uuid)
  AND NOT EXISTS (
    SELECT 1 FROM public.membership_permissions
    WHERE organization_id = :'org1'::uuid
      AND user_id = :'lifecycle_inactive_user'::uuid
      AND revoked_at is null
  )
  AND EXISTS (
    SELECT 1
    FROM public.unit_access_audit_events
    WHERE organization_id = :'org1'::uuid
      AND target_user_id = :'lifecycle_inactive_user'::uuid
      AND event_type = 'membership_scope_changed'
      AND actor_kind = 'user'
      AND actor_user_id = :'owner1'::uuid
      AND after_state ->> 'source' = 'professional_lifecycle'
  ),
  'active=false deactivates membership, revokes permissions and audits the human actor'
);

SELECT pg_temp.mk_user('lifecycle-unlink@test.local') AS lifecycle_unlink_user \gset
INSERT INTO public.memberships (organization_id, user_id, role, unit_id)
VALUES (:'org1'::uuid, :'lifecycle_unlink_user'::uuid, 'professional', :'unit1'::uuid);
INSERT INTO public.professionals (organization_id, user_id, name)
VALUES (:'org1'::uuid, :'lifecycle_unlink_user'::uuid, 'Profissional Lifecycle Unlink')
RETURNING id AS lifecycle_unlink_professional \gset
SELECT public.membership_permission_grant(
  :'org1'::uuid,
  :'owner1'::uuid,
  :'lifecycle_unlink_user'::uuid,
  'schedule:view_all'
);
SELECT lives_ok(
  format(
    'select public.professional_update(%L, %L, %L, %L::jsonb)',
    :'org1',
    :'owner1',
    :'lifecycle_unlink_professional',
    '{"user_id": null}'
  ),
  'unlinking a professional user invalidates its access lifecycle'
);
SELECT ok(
  NOT (SELECT active FROM public.memberships
       WHERE organization_id = :'org1'::uuid
         AND user_id = :'lifecycle_unlink_user'::uuid)
  AND NOT EXISTS (
    SELECT 1 FROM public.membership_permissions
    WHERE organization_id = :'org1'::uuid
      AND user_id = :'lifecycle_unlink_user'::uuid
      AND revoked_at is null
  ),
  'user unlink deactivates membership and revokes permissions'
);

SELECT throws_ok(
  format(
    'select public.professional_delete(%L, %L, %L)',
    :'org1', :'manager1', :'professional1'
  ),
  '42501',
  NULL,
  'manager cannot delete a professional'
);
SELECT throws_ok(
  format(
    'select public.professional_delete(%L, %L, %L)',
    :'org2', :'owner2', :'professional1'
  ),
  'P0002',
  NULL,
  'professional_delete rejects a professional from another tenant'
);

-- === Unit commands: Onda 0 fixes timezone and exposes no timezone parameter. ===
SELECT ok(
  to_regprocedure('public.unit_create(uuid,uuid,text,text)') is null,
  'unit_create exposes no timezone parameter in Onda 0'
);
SELECT (public.unit_create(
  :'org1'::uuid,
  :'owner1'::uuid,
  'Unidade Command'
)).id AS command_unit \gset
SELECT ok(
  EXISTS(
    SELECT 1
    FROM public.units
    WHERE organization_id = :'org1'::uuid
      AND id = :'command_unit'::uuid
      AND active
      AND NOT is_default
      AND timezone = 'America/Sao_Paulo'
  ),
  'unit_create persists a non-default active unit with the fixed timezone'
);
SELECT ok(
  EXISTS(
    SELECT 1
    FROM public.unit_access_audit_events
    WHERE organization_id = :'org1'::uuid
      AND unit_id = :'command_unit'::uuid
      AND event_type = 'unit_created'
      AND actor_kind = 'user'
      AND actor_user_id = :'owner1'::uuid
  ),
  'unit_create audits the human actor in the same transaction'
);
SELECT throws_ok(
  format(
    'select public.unit_create(%L, %L, %L)',
    :'org1', :'manager1', 'Unidade Indevida'
  ),
  '42501',
  NULL,
  'manager cannot create unit topology'
);
SELECT throws_ok(
  format(
    'select public.set_default_unit(%L, %L, %L)',
    :'org1', :'owner1', :'unit2'
  ),
  'P0002',
  NULL,
  'set_default_unit rejects a cross-tenant unit'
);
SELECT lives_ok(
  format(
    'select public.set_default_unit(%L, %L, %L)',
    :'org1', :'owner1', :'command_unit'
  ),
  'owner can promote an active unit to organization default'
);
SELECT ok(
  (SELECT is_default FROM public.units WHERE id = :'command_unit'::uuid)
    AND NOT (SELECT is_default FROM public.units WHERE id = :'unit1'::uuid),
  'set_default_unit preserves exactly one active default'
);
SELECT throws_ok(
  format(
    'update public.units set is_default = false where organization_id = %L and id = %L',
    :'org1', :'command_unit'
  ),
  '23514',
  NULL,
  'default trigger rejects direct removal of the only active default'
);
SELECT throws_ok(
  format(
    'update public.units set active = false where organization_id = %L and id = %L',
    :'org1', :'command_unit'
  ),
  '23514',
  NULL,
  'default trigger rejects direct deactivation of the only active default'
);
SELECT ok(
  EXISTS(
    SELECT 1
    FROM public.unit_access_audit_events
    WHERE organization_id = :'org1'::uuid
      AND unit_id = :'command_unit'::uuid
      AND event_type = 'default_changed'
      AND actor_user_id = :'owner1'::uuid
  ),
  'set_default_unit audits the default transition'
);
SELECT throws_ok(
  format(
    'select public.deactivate_unit(%L, %L, %L)',
    :'org1', :'owner1', :'command_unit'
  ),
  '23514',
  NULL,
  'deactivate_unit rejects the active default unit'
);
SELECT lives_ok(
  format(
    'select public.set_default_unit(%L, %L, %L)',
    :'org1', :'owner1', :'unit1'
  ),
  'owner can restore the original active default unit'
);
SELECT lives_ok(
  format(
    'select public.deactivate_unit(%L, %L, %L)',
    :'org1', :'owner1', :'command_unit'
  ),
  'owner can deactivate a non-default unit when another active unit remains'
);
SELECT ok(
  EXISTS(
    SELECT 1
    FROM public.unit_access_audit_events
    WHERE organization_id = :'org1'::uuid
      AND unit_id = :'command_unit'::uuid
      AND event_type = 'unit_deactivated'
      AND actor_user_id = :'owner1'::uuid
  ),
  'deactivate_unit audits the topology mutation'
);
SELECT throws_ok(
  format(
    'select public.deactivate_unit(%L, %L, %L)',
    :'org2', :'owner2', :'unit2'
  ),
  '23514',
  NULL,
  'deactivate_unit rejects removing the last active unit'
);
SELECT (public.unit_create(
  :'org1'::uuid,
  :'owner1'::uuid,
  'Unidade Vinculos'
)).id AS link_unit \gset
SELECT lives_ok(
  format(
    'select public.professional_unit_assign(%L, %L, %L, %L)',
    :'org1', :'manager1', :'professional1', :'link_unit'
  ),
  'manager can assign a professional to an active unit'
);
SELECT ok(
  EXISTS(
    SELECT 1
    FROM public.professional_units
    WHERE organization_id = :'org1'::uuid
      AND professional_id = :'professional1'::uuid
      AND unit_id = :'link_unit'::uuid
      AND active
  ),
  'professional_unit_assign persists the active tenant-safe link'
);
SELECT ok(
  EXISTS(
    SELECT 1
    FROM public.unit_access_audit_events
    WHERE organization_id = :'org1'::uuid
      AND professional_id = :'professional1'::uuid
      AND unit_id = :'link_unit'::uuid
      AND event_type = 'professional_unit_changed'
      AND actor_user_id = :'manager1'::uuid
      AND after_state ->> 'action' = 'assigned'
  ),
  'professional_unit_assign audits the manager actor'
);
SELECT count(*)::integer AS assign_audit_before
FROM public.unit_access_audit_events
WHERE organization_id = :'org1'::uuid
  AND professional_id = :'professional1'::uuid
  AND unit_id = :'link_unit'::uuid
  AND event_type = 'professional_unit_changed'
\gset
SELECT lives_ok(
  format(
    'select public.professional_unit_assign(%L, %L, %L, %L)',
    :'org1', :'manager1', :'professional1', :'link_unit'
  ),
  'repeating an active professional-unit assignment is idempotent'
);
SELECT is(
  (
    SELECT count(*)::integer
    FROM public.unit_access_audit_events
    WHERE organization_id = :'org1'::uuid
      AND professional_id = :'professional1'::uuid
      AND unit_id = :'link_unit'::uuid
      AND event_type = 'professional_unit_changed'
  ),
  :'assign_audit_before'::integer,
  'idempotent professional_unit_assign creates no duplicate audit event'
);
SELECT throws_ok(
  format(
    'select public.professional_unit_assign(%L, %L, %L, %L)',
    :'org1', :'manager1', :'professional1', :'unit2'
  ),
  'P0002',
  NULL,
  'professional_unit_assign rejects a cross-tenant unit'
);
SELECT lives_ok(
  format(
    'select public.professional_unit_revoke(%L, %L, %L, %L)',
    :'org1', :'manager1', :'professional1', :'link_unit'
  ),
  'manager can revoke an active professional-unit link'
);
SELECT ok(
  NOT EXISTS(
    SELECT 1
    FROM public.professional_units
    WHERE organization_id = :'org1'::uuid
      AND professional_id = :'professional1'::uuid
      AND unit_id = :'link_unit'::uuid
  )
  AND EXISTS(
    SELECT 1
    FROM public.unit_access_audit_events
    WHERE organization_id = :'org1'::uuid
      AND professional_id = :'professional1'::uuid
      AND unit_id = :'link_unit'::uuid
      AND actor_user_id = :'manager1'::uuid
      AND after_state ->> 'action' = 'deleted'
  ),
  'professional_unit_revoke deletes the link and the BEFORE DELETE trigger audits the actor'
);
SELECT throws_ok(
  format(
    'select public.professional_unit_assign(%L, %L, %L, %L)',
    :'org1', :'manager1', :'professional1', :'command_unit'
  ),
  '23514',
  NULL,
  'professional_unit_assign rejects an inactive unit'
);
SELECT throws_ok(
  format(
    'select public.professional_unit_revoke(%L, %L, %L, %L)',
    :'org1', :'manager1', :'authenticated_professional1', :'unit1'
  ),
  '23514',
  NULL,
  'professional_unit_revoke preserves the active link required by a professional membership scope'
);
SELECT throws_ok(
  format(
    'select public.membership_permission_grant(%L, %L, %L, %L)',
    :'org1', :'manager1', :'professional_user1', 'clients:view_all'
  ),
  '42501',
  NULL,
  'manager cannot grant professional permissions'
);
SELECT throws_ok(
  format(
    'select public.membership_permission_grant(%L, %L, %L, %L)',
    :'org1', :'owner1', :'reception1', 'clients:view_all'
  ),
  '23514',
  NULL,
  'membership_permission_grant rejects a reception membership'
);
SELECT throws_ok(
  format(
    'insert into public.membership_permissions (organization_id, user_id, permission_code, granted_by) values (%L, %L, %L, %L)',
    :'org1', :'reception1', 'clients:view_all', :'owner1'
  ),
  '23514',
  NULL,
  'database trigger rejects an active permission outside a professional scoped membership'
);
SELECT lives_ok(
  format(
    'select public.membership_permission_revoke(%L, %L, %L, %L)',
    :'org1', :'owner1', :'professional_user1', 'schedule:view_all'
  ),
  'owner can revoke an active professional permission'
);
SELECT ok(
  EXISTS(
    SELECT 1
    FROM public.membership_permissions
    WHERE organization_id = :'org1'::uuid
      AND user_id = :'professional_user1'::uuid
      AND permission_code = 'schedule:view_all'
      AND revoked_at is not null
      AND revoked_by = :'owner1'::uuid
  )
  AND EXISTS(
    SELECT 1
    FROM public.unit_access_audit_events
    WHERE organization_id = :'org1'::uuid
      AND target_user_id = :'professional_user1'::uuid
      AND event_type = 'permission_revoked'
      AND actor_user_id = :'owner1'::uuid
  ),
  'membership_permission_revoke persists revocation and audit atomically'
);
SELECT lives_ok(
  format(
    'select public.membership_permission_grant(%L, %L, %L, %L)',
    :'org1', :'owner1', :'professional_user1', 'schedule:view_all'
  ),
  'owner can grant a permission to an active scoped professional'
);
SELECT ok(
  EXISTS(
    SELECT 1
    FROM public.membership_permissions
    WHERE organization_id = :'org1'::uuid
      AND user_id = :'professional_user1'::uuid
      AND permission_code = 'schedule:view_all'
      AND revoked_at is null
      AND granted_by = :'owner1'::uuid
  )
  AND EXISTS(
    SELECT 1
    FROM public.unit_access_audit_events
    WHERE organization_id = :'org1'::uuid
      AND target_user_id = :'professional_user1'::uuid
      AND event_type = 'permission_granted'
      AND actor_user_id = :'owner1'::uuid
  ),
  'membership_permission_grant persists active permission and audit atomically'
);
SELECT throws_ok(
  format(
    'select public.membership_permission_grant(%L, %L, %L, %L)',
    :'org1', :'owner1', :'professional_user1', 'billing:admin'
  ),
  '22023',
  NULL,
  'membership_permission_grant rejects a permission outside the allowlist'
);
SELECT throws_ok(
  format(
    'select public.membership_permission_grant(%L, %L, %L, %L)',
    :'org1', :'owner2', :'professional_user1', 'clients:view_all'
  ),
  '42501',
  NULL,
  'membership_permission_grant rejects an actor from another tenant'
);
SELECT throws_ok(
  format(
    'select public.membership_scope_set(%L, %L, %L, %L, %L, %L)',
    :'org1', :'manager1', :'reception1', 'reception', :'unit1', 'true'
  ),
  '42501',
  NULL,
  'manager cannot change membership role or unit scope'
);
SELECT throws_ok(
  format(
    'select public.membership_scope_set(%L, %L, %L, %L, null, %L)',
    :'org1', :'owner1', :'reception1', 'reception', 'true'
  ),
  '22023',
  NULL,
  'membership_scope_set requires an explicit unit for reception'
);
SELECT throws_ok(
  format(
    'select public.membership_scope_set(%L, %L, %L, %L, %L, %L)',
    :'org1', :'owner1', :'reception1', 'reception', :'unit2', 'true'
  ),
  'P0002',
  NULL,
  'membership_scope_set rejects a cross-tenant unit'
);
SELECT lives_ok(
  format(
    'select public.membership_scope_set(%L, %L, %L, %L, %L, %L)',
    :'org1', :'owner1', :'outsider', 'professional', :'unit1', 'true'
  ),
  'membership_scope_set permits a pending professional profile while permissions remain fail-closed'
);
SELECT throws_ok(
  format(
    'select public.membership_permission_grant(%L, %L, %L, %L)',
    :'org1', :'owner1', :'outsider', 'schedule:view_all'
  ),
  '23514',
  NULL,
  'pending professional membership cannot receive permissions before an active unit link exists'
);
SELECT lives_ok(
  format(
    'select public.membership_scope_set(%L, %L, %L, %L, null, %L)',
    :'org1', :'owner1', :'professional_user1', 'manager', 'true'
  ),
  'owner can promote a professional membership to an organization-wide role'
);
SELECT ok(
  EXISTS(
    SELECT 1
    FROM public.memberships
    WHERE organization_id = :'org1'::uuid
      AND user_id = :'professional_user1'::uuid
      AND role = 'manager'
      AND unit_id is null
      AND active
  )
  AND NOT EXISTS(
    SELECT 1
    FROM public.membership_permissions
    WHERE organization_id = :'org1'::uuid
      AND user_id = :'professional_user1'::uuid
      AND revoked_at is null
  ),
  'promotion to org-wide clears unit scope and revokes professional permissions'
);
SELECT ok(
  EXISTS(
    SELECT 1
    FROM public.unit_access_audit_events
    WHERE organization_id = :'org1'::uuid
      AND target_user_id = :'professional_user1'::uuid
      AND event_type = 'membership_scope_changed'
      AND actor_user_id = :'owner1'::uuid
      AND after_state ->> 'role' = 'manager'
  )
  AND EXISTS(
    SELECT 1
    FROM public.unit_access_audit_events
    WHERE organization_id = :'org1'::uuid
      AND target_user_id = :'professional_user1'::uuid
      AND event_type = 'permission_revoked'
      AND actor_user_id = :'owner1'::uuid
  ),
  'membership_scope_set audits both scope mutation and automatic permission revocation'
);
SELECT lives_ok(
  format(
    'select public.membership_scope_set(%L, %L, %L, %L, null, %L)',
    :'org1', :'owner1', :'reception1', 'manager', 'true'
  ),
  'owner can promote reception to an organization-wide role'
);
SELECT lives_ok(
  format(
    'select public.membership_scope_set(%L, %L, %L, %L, %L, %L)',
    :'org1', :'owner1', :'reception1', 'reception', :'unit1', 'true'
  ),
  'owner can assign an explicit active unit when returning to a scoped role'
);
SELECT count(*)::integer AS scope_audit_before
FROM public.unit_access_audit_events
WHERE organization_id = :'org1'::uuid
  AND target_user_id = :'reception1'::uuid
  AND event_type = 'membership_scope_changed'
\gset
SELECT lives_ok(
  format(
    'select public.membership_scope_set(%L, %L, %L, %L, %L, %L)',
    :'org1', :'owner1', :'reception1', 'reception', :'unit1', 'true'
  ),
  'repeating an identical membership scope is idempotent'
);
SELECT is(
  (
    SELECT count(*)::integer
    FROM public.unit_access_audit_events
    WHERE organization_id = :'org1'::uuid
      AND target_user_id = :'reception1'::uuid
      AND event_type = 'membership_scope_changed'
  ),
  :'scope_audit_before'::integer,
  'idempotent membership_scope_set creates no duplicate audit event'
);
SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = ANY(ARRAY[
        'unit_create',
        'set_default_unit',
        'deactivate_unit',
        'professional_unit_assign',
        'professional_unit_revoke',
        'professional_update',
        'professional_delete',
        'membership_permission_grant',
        'membership_permission_revoke',
        'membership_scope_set'
      ])
      AND (
        has_function_privilege('anon', p.oid, 'EXECUTE')
        OR has_function_privilege('authenticated', p.oid, 'EXECUTE')
        OR NOT has_function_privilege('service_role', p.oid, 'EXECUTE')
      )
  ),
  'all unit commands revoke anon/authenticated EXECUTE and grant only service_role'
);

SELECT * FROM finish();
ROLLBACK;
