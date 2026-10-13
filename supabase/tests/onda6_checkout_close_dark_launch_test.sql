BEGIN;
SELECT plan(25);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('onda6-dark-launch-owner@test.local') AS owner \gset
SELECT pg_temp.mk_user('onda6-dark-launch-reception@test.local') AS reception \gset
SELECT (public.create_organization(:'owner'::uuid, 'Org Onda6 Dark Launch', 'org-onda6-dark-launch')).id AS org \gset
SELECT id AS unit FROM public.units WHERE organization_id = :'org'::uuid AND is_default \gset
INSERT INTO public.memberships (organization_id, user_id, role, unit_id)
VALUES (:'org'::uuid, :'reception'::uuid, 'reception', :'unit'::uuid);
INSERT INTO public.products (organization_id, sku, name, price_cents, cost_cents, stock_on_hand)
VALUES (:'org'::uuid, 'O6-DARK-001', 'Produto Dark Launch', 1000, 100, 10)
RETURNING id AS product \gset
INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
VALUES (:'org'::uuid, 'Grupo Dark Launch', 'fixed', 100)
RETURNING id AS service_group \gset
INSERT INTO public.professionals (organization_id, name)
VALUES (:'org'::uuid, 'Profissional Dark Launch')
RETURNING id AS professional \gset
INSERT INTO public.services (organization_id, service_group_id, name, price_cents, duration_minutes)
VALUES (:'org'::uuid, :'service_group'::uuid, 'Servico Dark Launch', 500, 30)
RETURNING id AS service \gset

-- Flag ausente/desligada: o fechamento continua legado, com o contrato de
-- resposta e os efeitos existentes, sem criar nenhum fato da Onda 6.
SELECT public.checkout_close(
  :'org'::uuid,
  :'owner'::uuid,
  'onda6-dark-legacy-001',
  jsonb_build_object(
    'items', jsonb_build_array(
      jsonb_build_object('kind', 'product', 'id', :'product'::uuid, 'quantity', 1),
      jsonb_build_object('kind', 'service', 'id', :'service'::uuid, 'quantity', 1, 'professional_id', :'professional'::uuid)
    ),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount_cents', 1500))
  )
) AS legacy_response \gset
SELECT (:'legacy_response'::jsonb ->> 'order_id')::uuid AS legacy_order \gset
SELECT is(
  :'legacy_response'::jsonb - 'order_id',
  jsonb_build_object('organization_id', :'org'::uuid, 'total_cents', 1500, 'status', 'closed', 'deposit_applied_cents', 0),
  'flag absent preserves the exact legacy checkout response shape'
);
SELECT is((:'legacy_response'::jsonb ->> 'status'), 'closed', 'flag absent preserves the legacy closed response');
SELECT is((:'legacy_response'::jsonb ->> 'total_cents')::bigint, 1500::bigint, 'flag absent preserves legacy total reconciliation');
SELECT is((select stock_on_hand from public.products where id = :'product'::uuid), 9, 'flag absent keeps the legacy stock decrement');
SELECT is((select count(*)::int from public.cash_entries where organization_id = :'org'::uuid and order_id = :'legacy_order'::uuid and kind = 'sale'), 1, 'flag absent keeps the legacy cash entry');
SELECT is((select count(*)::int from public.order_revisions where organization_id = :'org'::uuid and order_id = :'legacy_order'::uuid), 0, 'flag absent creates no snapshot for a legacy order');
SELECT is((select count(*)::int from public.order_ledger_links where organization_id = :'org'::uuid and order_id = :'legacy_order'::uuid), 0, 'flag absent creates no ledger link for a legacy order');

UPDATE public.organizations
SET settings = jsonb_set(coalesce(settings, '{}'::jsonb), '{checkout_reopen_enabled}', 'true'::jsonb, true)
WHERE id = :'org'::uuid;

SELECT public.checkout_close(
  :'org'::uuid,
  :'owner'::uuid,
  'onda6-dark-legacy-001',
  jsonb_build_object(
    'items', jsonb_build_array(
      jsonb_build_object('kind', 'product', 'id', :'product'::uuid, 'quantity', 1),
      jsonb_build_object('kind', 'service', 'id', :'service'::uuid, 'quantity', 1, 'professional_id', :'professional'::uuid)
    ),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount_cents', 1500))
  )
) AS legacy_replay \gset
SELECT is(:'legacy_replay'::jsonb, :'legacy_response'::jsonb, 'enabling the flag never version-controls a previously completed legacy replay');
SELECT is((select count(*)::int from public.order_ledger_links where organization_id = :'org'::uuid and order_id = :'legacy_order'::uuid), 0, 'legacy replay remains without a closure link after the flag changes');

-- Reception continua usando somente o Command autorizado; a primitive privada
-- segue sem grant externo, mesmo no ramo ativado.
SELECT public.checkout_close(
  :'org'::uuid,
  :'reception'::uuid,
  'onda6-dark-versioned-001',
  jsonb_build_object(
    'items', jsonb_build_array(
      jsonb_build_object('kind', 'product', 'id', :'product'::uuid, 'quantity', 1),
      jsonb_build_object('kind', 'service', 'id', :'service'::uuid, 'quantity', 1, 'professional_id', :'professional'::uuid)
    ),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount_cents', 1500))
  )
) AS versioned_response \gset
SELECT (:'versioned_response'::jsonb ->> 'order_id')::uuid AS versioned_order \gset
SELECT is(
  :'versioned_response'::jsonb - 'order_id',
  jsonb_build_object('organization_id', :'org'::uuid, 'total_cents', 1500, 'status', 'closed', 'deposit_applied_cents', 0),
  'flag enabled preserves the exact legacy checkout response shape'
);
SELECT is((:'versioned_response'::jsonb ->> 'status'), 'closed', 'reception can still close checkout with the flag enabled');
SELECT ok(
  NOT has_function_privilege('authenticated', 'private.checkout_ledger_post(uuid, uuid, text, uuid, integer, text)', 'EXECUTE'),
  'flag enabled does not grant reception direct access to the private journal primitive'
);
SELECT is(
  (select count(*)::int from public.order_ledger_links
    where organization_id = :'org'::uuid and order_id = :'versioned_order'::uuid and revision_number = 1 and kind = 'closure'),
  1,
  'flag enabled creates exactly one closure ledger link'
);
SELECT is(
  (select count(*)::int from public.order_revisions where organization_id = :'org'::uuid and order_id = :'versioned_order'::uuid and revision_number = 1),
  1,
  'flag enabled creates snapshot v1 in the same checkout'
);
SELECT is(
  (select snapshot -> 'order' ->> 'total_cents' from public.order_revisions where organization_id = :'org'::uuid and order_id = :'versioned_order'::uuid and revision_number = 1)::bigint,
  1500::bigint,
  'snapshot stores canonical order totals'
);
SELECT is(
  (select jsonb_array_length(snapshot -> 'items') from public.order_revisions where organization_id = :'org'::uuid and order_id = :'versioned_order'::uuid and revision_number = 1),
  2,
  'snapshot stores the immutable item facts'
);
SELECT is(
  (select jsonb_array_length(snapshot -> 'payments') from public.order_revisions where organization_id = :'org'::uuid and order_id = :'versioned_order'::uuid and revision_number = 1),
  1,
  'snapshot stores the immutable payment facts'
);
SELECT is(
  (select snapshot -> 'ledger' ->> 'closure_transaction_id' from public.order_revisions where organization_id = :'org'::uuid and order_id = :'versioned_order'::uuid and revision_number = 1)::uuid,
  (select ledger_transaction_id from public.order_ledger_links
    where organization_id = :'org'::uuid and order_id = :'versioned_order'::uuid and revision_number = 1 and kind = 'closure'),
  'snapshot and closure link reference the same ledger transaction'
);
SELECT is(
  (select count(*)::int
     from public.kortex_ledger_entries e
     join public.order_ledger_links l on l.ledger_transaction_id = e.transaction_id
    where l.organization_id = :'org'::uuid and l.order_id = :'versioned_order'::uuid
      and l.revision_number = 1 and l.kind = 'closure'),
  5,
  'flag enabled posts the balanced checkout journal'
);

-- Falha da primitive de journal precisa abortar o mesmo statement: nem a
-- comanda nem seus efeitos operacionais podem sobreviver parcialmente.
SELECT count(*)::int AS orders_before_failure FROM public.orders WHERE organization_id = :'org'::uuid \gset
SELECT count(*)::int AS payments_before_failure FROM public.payments WHERE organization_id = :'org'::uuid \gset
SELECT count(*)::int AS cash_before_failure FROM public.cash_entries WHERE organization_id = :'org'::uuid \gset
SELECT count(*)::int AS movements_before_failure FROM public.inventory_movements WHERE organization_id = :'org'::uuid \gset
CREATE OR REPLACE FUNCTION private.checkout_ledger_post(
  p_organization_id uuid, p_actor_user_id uuid, p_parent_idempotency_key text,
  p_order_id uuid, p_revision_number integer, p_command text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private, extensions
AS $$ BEGIN RAISE EXCEPTION 'simulated journal failure' USING ERRCODE = 'P0001'; END; $$;
SELECT throws_ok(
  format(
    $$select public.checkout_close(%L, %L, 'onda6-dark-journal-failure-001', jsonb_build_object(
      'items', jsonb_build_array(jsonb_build_object('kind', 'product', 'id', %L, 'quantity', 1)),
      'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount_cents', 1000))
    ))$$,
    :'org', :'owner', :'product'
  ),
  'P0001', 'simulated journal failure',
  'journal failure aborts checkout_close'
);
SELECT is((select count(*)::int from public.orders where organization_id = :'org'::uuid), :'orders_before_failure'::int, 'journal failure rolls back the order');
SELECT is((select count(*)::int from public.payments where organization_id = :'org'::uuid), :'payments_before_failure'::int, 'journal failure rolls back payments');
SELECT is((select count(*)::int from public.cash_entries where organization_id = :'org'::uuid), :'cash_before_failure'::int, 'journal failure rolls back cash');
SELECT is((select count(*)::int from public.inventory_movements where organization_id = :'org'::uuid), :'movements_before_failure'::int, 'journal failure rolls back stock movements');
SELECT is((select stock_on_hand from public.products where id = :'product'::uuid), 8, 'journal failure rolls back the stock decrement');

SELECT * FROM finish();
ROLLBACK;
