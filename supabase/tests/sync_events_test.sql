BEGIN;
SELECT plan(12);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('owner@test.local') AS owner \gset

-- 1. Setup Org
SELECT (public.create_organization(:'owner'::uuid, 'Sync Corp', 'sync-corp')).id AS org \gset

-- 2. Test RLS
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.sync_events', 'SELECT'),
  'authenticated role cannot SELECT from sync_events directly'
);
SELECT ok(
  NOT has_table_privilege('anon', 'public.sync_events', 'SELECT'),
  'anon role cannot SELECT from sync_events directly'
);
SELECT ok(
  has_table_privilege('service_role', 'public.sync_events', 'SELECT'),
  'service_role can SELECT from sync_events'
);
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE relnamespace = 'public'::regnamespace AND relname = 'sync_events'),
  'public.sync_events has RLS enabled'
);
SELECT is(
  (SELECT count(*)::integer FROM pg_policies WHERE schemaname = 'public' AND tablename = 'sync_events'),
  0,
  'public.sync_events has zero RLS policies (deny-all by design, only service_role reads via BYPASSRLS)'
);

-- 3. Insert Client and check sync event
INSERT INTO public.clients (organization_id, name, phone, email, created_by)
VALUES (:'org'::uuid, 'Test Client', '123456789', 'client@test.local', :'owner'::uuid)
RETURNING id AS client_id \gset

SELECT is(
  (SELECT count(*)::integer FROM public.sync_events WHERE table_name = 'clients' AND action = 'INSERT'),
  1,
  'INSERT on clients creates a sync_event'
);

SELECT is(
  (SELECT record_id FROM public.sync_events WHERE table_name = 'clients' AND action = 'INSERT'),
  :'client_id'::uuid,
  'sync_event has correct record_id'
);

SELECT is(
  (SELECT (payload->>'name') FROM public.sync_events WHERE table_name = 'clients' AND action = 'INSERT'),
  'Test Client',
  'sync_event payload contains the correct client name'
);

-- 4. Update Client and check sync event
UPDATE public.clients
SET phone = '987654321'
WHERE id = :'client_id'::uuid;

SELECT is(
  (SELECT count(*)::integer FROM public.sync_events WHERE table_name = 'clients' AND action = 'UPDATE'),
  1,
  'UPDATE on clients creates a sync_event'
);

SELECT is(
  (SELECT (payload->>'phone') FROM public.sync_events WHERE table_name = 'clients' AND action = 'UPDATE'),
  '987654321',
  'sync_event payload contains updated client phone'
);

-- 5. Delete Client and check sync event
DELETE FROM public.clients
WHERE id = :'client_id'::uuid;

SELECT is(
  (SELECT count(*)::integer FROM public.sync_events WHERE table_name = 'clients' AND action = 'DELETE'),
  1,
  'DELETE on clients creates a sync_event'
);

SELECT is(
  (SELECT (payload->>'name') FROM public.sync_events WHERE table_name = 'clients' AND action = 'DELETE'),
  'Test Client',
  'DELETE sync_event payload contains old client name'
);

SELECT * FROM finish();
ROLLBACK;
