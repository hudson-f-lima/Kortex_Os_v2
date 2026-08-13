BEGIN;
SELECT plan(7);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('onda6-revision-owner@test.local') AS owner \gset
SELECT (public.create_organization(:'owner'::uuid, 'Org Onda6 Revisions', 'org-onda6-revisions')).id AS org \gset
SELECT id AS unit FROM public.units WHERE organization_id = :'org'::uuid AND is_default \gset
INSERT INTO public.orders (
  organization_id, unit_id, status, subtotal_cents, total_cents, created_by
) VALUES (
  :'org'::uuid, :'unit'::uuid, 'closed', 0, 0, :'owner'::uuid
) RETURNING id AS order_id \gset
INSERT INTO public.order_revisions (
  organization_id, unit_id, order_id, revision_number, snapshot, closed_by, closed_at
) VALUES (
  :'org'::uuid, :'unit'::uuid, :'order_id'::uuid, 1, '{"total_cents": 0}'::jsonb, :'owner'::uuid, now()
) RETURNING id AS revision_id \gset

-- Behavior 1 (issue 055): todo pedido tem uma revisão corrente explícita.
-- O contrato começa pela coluna; o default e o backfill serão cobertos no
-- próximo ciclo, depois que esta presença física estiver GREEN.
SELECT has_column(
  'public',
  'orders',
  'current_revision',
  'orders exposes current_revision for versioned checkout'
);

-- Behavior 4 (issue 055): snapshot fechado é append-only.
SELECT throws_ok(
  format(
    'update public.order_revisions set snapshot = %L::jsonb where id = %L::uuid',
    '{"total_cents": 1}',
    :'revision_id'
  ),
  '55000',
  'order revision is immutable',
  'closed order revision rejects UPDATE'
);

SELECT throws_ok(
  format(
    'delete from public.order_revisions where id = %L::uuid',
    :'revision_id'
  ),
  '55000',
  'order revision is immutable',
  'closed order revision rejects DELETE'
);

-- Behavior 3 (issue 055): cada fechamento terá um registro histórico próprio.
SELECT has_table(
  'public',
  'order_revisions',
  'order_revisions stores immutable order-close snapshots'
);

-- Behavior 6 (issue 055): cada tentativa mantém seus eventos auditáveis.
SELECT has_table(
  'public',
  'order_reopen_attempt_events',
  'order_reopen_attempt_events records the reopen lifecycle'
);

-- Behavior 5 (issue 055): uma reabertura é uma tentativa distinta da revisão.
SELECT has_table(
  'public',
  'order_reopen_attempts',
  'order_reopen_attempts records a governed reopen attempt'
);

-- Behavior 2 (issue 055): pagamentos também pertencem a uma revisão do pedido.
SELECT has_column(
  'public',
  'payments',
  'revision_number',
  'payments exposes revision_number for versioned checkout'
);

SELECT * FROM finish();
ROLLBACK;
