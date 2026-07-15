-- Test suite for RLS on professional_service_capabilities table

begin;
select plan(32);

-- Setup: Create test data
do $$
declare
  v_org_owner_id uuid;
  v_org_id uuid;
  v_admin_id uuid;
  v_manager_id uuid;
  v_reception_id uuid;
  v_professional_id uuid;
  v_service_id uuid;
begin
  -- Create users
  insert into auth.users(id, email, raw_user_meta_data) values
    ('550e8400-0001-0001-0001-000000000001'::uuid, 'owner@test.com', '{}'),
    ('550e8400-0001-0001-0001-000000000002'::uuid, 'admin@test.com', '{}'),
    ('550e8400-0001-0001-0001-000000000003'::uuid, 'manager@test.com', '{}'),
    ('550e8400-0001-0001-0001-000000000004'::uuid, 'reception@test.com', '{}'),
    ('550e8400-0001-0001-0001-000000000005'::uuid, 'professional@test.com', '{}');

  v_org_owner_id := '550e8400-0001-0001-0001-000000000001'::uuid;
  v_admin_id := '550e8400-0001-0001-0001-000000000002'::uuid;
  v_manager_id := '550e8400-0001-0001-0001-000000000003'::uuid;
  v_reception_id := '550e8400-0001-0001-0001-000000000004'::uuid;
  v_professional_id := '550e8400-0001-0001-0001-000000000005'::uuid;

  -- Create org
  insert into public.organizations(id, name, slug, active) values
    ('550e8400-a000-0000-0000-000000000001'::uuid, 'Test Org', 'test-org', true);
  v_org_id := '550e8400-a000-0000-0000-000000000001'::uuid;

  -- Create memberships
  insert into public.memberships(organization_id, user_id, role, active) values
    (v_org_id, v_org_owner_id, 'owner', true),
    (v_org_id, v_admin_id, 'admin', true),
    (v_org_id, v_manager_id, 'manager', true),
    (v_org_id, v_reception_id, 'reception', true),
    (v_org_id, v_professional_id, 'professional', true);

  -- Create professional
  insert into public.professionals(id, organization_id, name, active) values
    ('550e8400-b000-0000-0000-000000000001'::uuid, v_org_id, 'Ana Silva', true);

  -- Create service
  insert into public.services(id, organization_id, name, price_cents, duration_minutes, active) values
    ('550e8400-c000-0000-0000-000000000001'::uuid, v_org_id, 'Haircut', 5000, 30, true);

  -- Create service group (needed for other services)
  insert into public.service_groups(id, organization_id, name, default_commission_type, default_commission_value, active) values
    ('550e8400-d000-0000-0000-000000000001'::uuid, v_org_id, 'Hair', 'percentage', 2000, true);

  -- Update service to have a group
  update public.services
  set service_group_id = '550e8400-d000-0000-0000-000000000001'::uuid
  where id = '550e8400-c000-0000-0000-000000000001'::uuid;

  -- Set auth context for the rest
  perform auth.set_claim('sub', v_org_owner_id::text);

  -- Create capability as owner
  insert into public.professional_service_capabilities(
    id, organization_id, professional_id, service_id,
    duration_override_minutes, buffer_before_min, buffer_after_min, price_override_cents, active
  ) values
    ('550e8400-e000-0000-0000-000000000001'::uuid, v_org_id, '550e8400-b000-0000-0000-000000000001'::uuid,
     '550e8400-c000-0000-0000-000000000001'::uuid, 45, 10, 5, 6000, true),
    ('550e8400-e000-0000-0000-000000000002'::uuid, v_org_id, '550e8400-b000-0000-0000-000000000001'::uuid,
     '550e8400-c000-0000-0000-000000000001'::uuid, 60, 15, 10, 7000, false);
end $$;

-- Test: SELECT access
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"550e8400-0001-0001-0001-000000000001"}';
select is(count(*) > 0, true, 'owner can select capabilities')
from public.professional_service_capabilities;

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"550e8400-0001-0001-0001-000000000002"}';
select is(count(*) > 0, true, 'admin can select capabilities')
from public.professional_service_capabilities;

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"550e8400-0001-0001-0001-000000000003"}';
select is(count(*) > 0, true, 'manager can select capabilities')
from public.professional_service_capabilities;

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"550e8400-0001-0001-0001-000000000004"}';
select is(count(*) > 0, true, 'reception can select capabilities')
from public.professional_service_capabilities;

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"550e8400-0001-0001-0001-000000000005"}';
select is(count(*) > 0, true, 'professional can select capabilities')
from public.professional_service_capabilities;

-- Test: INSERT access
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"550e8400-0001-0001-0001-000000000001"}';
insert into public.professional_service_capabilities(
  organization_id, professional_id, service_id, duration_override_minutes
) values ('550e8400-a000-0000-0000-000000000001'::uuid, '550e8400-b000-0000-0000-000000000001'::uuid,
         '550e8400-c000-0000-0000-000000000001'::uuid, 40)
on conflict do nothing;
select ok(found, 'owner can insert capability');

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"550e8400-0001-0001-0001-000000000004"}';
begin;
insert into public.professional_service_capabilities(
  organization_id, professional_id, service_id, duration_override_minutes
) values ('550e8400-a000-0000-0000-000000000001'::uuid, '550e8400-b000-0000-0000-000000000001'::uuid,
         '550e8400-c000-0000-0000-000000000001'::uuid, 50);
select throws_like(
  $inner$
    rollback;
  $inner$,
  'new row violates row-level security policy',
  'reception cannot insert capability'
);
end;

-- Test: UPDATE access
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"550e8400-0001-0001-0001-000000000001"}';
update public.professional_service_capabilities
set duration_override_minutes = 55
where id = '550e8400-e000-0000-0000-000000000001'::uuid;
select ok(found, 'owner can update capability');

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"550e8400-0001-0001-0001-000000000004"}';
begin;
update public.professional_service_capabilities
set duration_override_minutes = 70
where id = '550e8400-e000-0000-0000-000000000001'::uuid;
select throws_like(
  $inner$
    rollback;
  $inner$,
  'new row violates row-level security policy',
  'reception cannot update capability'
);
end;

-- Test: DELETE access
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"550e8400-0001-0001-0001-000000000002"}';
delete from public.professional_service_capabilities
where id = '550e8400-e000-0000-0000-000000000002'::uuid;
select ok(found, 'admin can delete capability');

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"550e8400-0001-0001-0001-000000000003"}';
begin;
delete from public.professional_service_capabilities
where id = '550e8400-e000-0000-0000-000000000001'::uuid;
select throws_like(
  $inner$
    rollback;
  $inner$,
  'new row violates row-level security policy',
  'manager cannot delete capability'
);
end;

-- Test: Unique constraint on (org_id, professional_id, service_id)
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"550e8400-0001-0001-0001-000000000001"}';
begin;
insert into public.professional_service_capabilities(
  organization_id, professional_id, service_id, duration_override_minutes
) values ('550e8400-a000-0000-0000-000000000001'::uuid, '550e8400-b000-0000-0000-000000000001'::uuid,
         '550e8400-c000-0000-0000-000000000001'::uuid, 50);
select throws_ok('unique_violation_attempt', 'duplicate capability rejected');
rollback;
end;

select * from finish();
commit;
