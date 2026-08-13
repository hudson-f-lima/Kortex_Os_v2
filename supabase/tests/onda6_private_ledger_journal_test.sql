BEGIN;
SELECT plan(27);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT has_function(
  'private',
  'kortex_ledger_post_entries',
  ARRAY['uuid', 'uuid', 'text', 'uuid', 'jsonb'],
  'the shared ledger write primitive exists only in the private schema'
);

-- New PostgreSQL functions otherwise start executable by PUBLIC. Both direct
-- privilege inspection and attempted calls prove that no external role can
-- bypass the server-owned Commands.
SELECT ok(
  NOT has_function_privilege('authenticated', 'private.kortex_ledger_post_entries(uuid, uuid, text, uuid, jsonb)', 'EXECUTE'),
  'authenticated cannot execute the shared private ledger primitive'
);
SELECT ok(
  NOT has_function_privilege('service_role', 'private.kortex_ledger_post_entries(uuid, uuid, text, uuid, jsonb)', 'EXECUTE'),
  'service_role cannot execute the shared private ledger primitive directly'
);
SELECT ok(
  NOT has_function_privilege('authenticated', 'private.checkout_ledger_post(uuid, uuid, text, uuid, integer, text)', 'EXECUTE'),
  'authenticated cannot execute the checkout journal primitive'
);
SELECT ok(
  NOT has_function_privilege('service_role', 'private.checkout_ledger_post(uuid, uuid, text, uuid, integer, text)', 'EXECUTE'),
  'service_role cannot execute the checkout journal primitive directly'
);

SET LOCAL ROLE authenticated;
SELECT throws_ok(
  $$select private.kortex_ledger_post_entries('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'direct-call-001', '00000000-0000-0000-0000-000000000001', '[]'::jsonb)$$,
  '42501', NULL,
  'authenticated direct call to private.kortex_ledger_post_entries is denied'
);
SELECT throws_ok(
  $$select private.checkout_ledger_post('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'direct-call-002', '00000000-0000-0000-0000-000000000001', 1, 'checkout_close')$$,
  '42501', NULL,
  'authenticated direct call to private.checkout_ledger_post is denied'
);
RESET ROLE;

SET LOCAL ROLE service_role;
SELECT throws_ok(
  $$select private.kortex_ledger_post_entries('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'direct-call-003', '00000000-0000-0000-0000-000000000001', '[]'::jsonb)$$,
  '42501', NULL,
  'service_role direct call to private.kortex_ledger_post_entries is denied'
);
SELECT throws_ok(
  $$select private.checkout_ledger_post('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'direct-call-004', '00000000-0000-0000-0000-000000000001', 1, 'checkout_close')$$,
  '42501', NULL,
  'service_role direct call to private.checkout_ledger_post is denied'
);
RESET ROLE;

-- Fixture: a mixed sale whose three-cent discount exercises checkout_close's
-- largest-remainder allocation, with two professionals and a tip.
SELECT pg_temp.mk_user('onda6-ledger-owner@test.local') AS owner \gset
SELECT pg_temp.mk_user('onda6-ledger-reception@test.local') AS reception \gset
SELECT (public.create_organization(:'owner'::uuid, 'Org Onda6 Ledger', 'org-onda6-ledger')).id AS org \gset
SELECT id AS unit FROM public.units WHERE organization_id = :'org'::uuid AND is_default \gset
INSERT INTO public.memberships (organization_id, user_id, role, unit_id)
VALUES (:'org'::uuid, :'reception'::uuid, 'reception', :'unit'::uuid);
INSERT INTO public.professionals (organization_id, name) VALUES
  (:'org'::uuid, 'Profissional Ledger Um'),
  (:'org'::uuid, 'Profissional Ledger Dois');
SELECT id AS professional_one FROM public.professionals
WHERE organization_id = :'org'::uuid AND name = 'Profissional Ledger Um' \gset
SELECT id AS professional_two FROM public.professionals
WHERE organization_id = :'org'::uuid AND name = 'Profissional Ledger Dois' \gset
INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
VALUES (:'org'::uuid, 'Grupo Ledger', 'fixed', 0) RETURNING id AS service_group \gset
INSERT INTO public.services (organization_id, service_group_id, name, price_cents, duration_minutes)
VALUES (:'org'::uuid, :'service_group'::uuid, 'Servico Ledger Um', 501, 30)
RETURNING id AS service_one \gset
INSERT INTO public.services (organization_id, service_group_id, name, price_cents, duration_minutes)
VALUES (:'org'::uuid, :'service_group'::uuid, 'Servico Ledger Dois', 499, 30)
RETURNING id AS service_two \gset
INSERT INTO public.products (organization_id, sku, name, price_cents, cost_cents, stock_on_hand)
VALUES (:'org'::uuid, 'LEDGER-001', 'Produto Ledger', 1000, 100, 10)
RETURNING id AS product \gset
INSERT INTO public.orders (
  organization_id, unit_id, status, subtotal_cents, discount_cents, tip_cents, total_cents, created_by, closed_at
) VALUES (
  :'org'::uuid, :'unit'::uuid, 'closed', 2000, 3, 100, 2097, :'owner'::uuid, now()
) RETURNING id AS order_id \gset
INSERT INTO public.order_items (
  organization_id, unit_id, order_id, kind, service_id, description, quantity, unit_price_cents, total_cents,
  professional_id, commission_type, commission_value, commission_cents
) VALUES
  (:'org'::uuid, :'unit'::uuid, :'order_id'::uuid, 'service', :'service_one'::uuid, 'Servico Ledger Um', 1, 501, 501, :'professional_one'::uuid, 'fixed', 100, 100),
  (:'org'::uuid, :'unit'::uuid, :'order_id'::uuid, 'service', :'service_two'::uuid, 'Servico Ledger Dois', 1, 499, 499, :'professional_two'::uuid, 'fixed', 50, 50);
INSERT INTO public.order_items (
  organization_id, unit_id, order_id, kind, product_id, description, quantity, unit_price_cents, total_cents
) VALUES (
  :'org'::uuid, :'unit'::uuid, :'order_id'::uuid, 'product', :'product'::uuid, 'Produto Ledger', 1, 1000, 1000
);
INSERT INTO public.payments (organization_id, unit_id, order_id, revision_number, method, amount_cents)
VALUES (:'org'::uuid, :'unit'::uuid, :'order_id'::uuid, 1, 'pix', 2097);

SELECT (public.unit_create(:'org'::uuid, :'owner'::uuid, 'Unidade Ledger Restrita')).id AS other_unit \gset
INSERT INTO public.orders (
  organization_id, unit_id, status, subtotal_cents, discount_cents, tip_cents, total_cents, created_by, closed_at
) VALUES (
  :'org'::uuid, :'other_unit'::uuid, 'closed', 0, 0, 0, 0, :'owner'::uuid, now()
) RETURNING id AS other_unit_order_id \gset
SELECT throws_ok(
  format('select private.checkout_ledger_post(%L, %L, %L, %L, 1, %L)',
    :'org', :'reception', 'reception-cross-unit-001', :'other_unit_order_id', 'checkout_close'
  ),
  '42501', NULL,
  'reception cannot invoke checkout ledger context for an order outside its membership unit'
);

SELECT throws_ok(
  format(
    'select public.kortex_ledger_post(%L, %L, %L, %L, %L::jsonb)',
    :'org', :'reception', 'reception-arbitrary-ledger', :'unit',
    jsonb_build_array(
      jsonb_build_object('kind', 'cash', 'direction', 'debit', 'amount_cents', 1),
      jsonb_build_object('kind', 'revenue_service', 'direction', 'credit', 'amount_cents', 1)
    )::text
  ),
  '42501', NULL,
  'reception still cannot use the administrative public ledger RPC'
);

SELECT (private.checkout_ledger_post(
  :'org'::uuid, :'owner'::uuid, 'checkout-parent-key-001', :'order_id'::uuid, 1, 'checkout_close'
) ->> 'transaction_id')::uuid AS transaction_id \gset
SELECT ok(
  exists (
    select 1 from public.kortex_ledger_transactions
    where id = :'transaction_id'::uuid
      and organization_id = :'org'::uuid
      and unit_id = :'unit'::uuid
  ),
  'authorized checkout_close context posts through the private ledger primitive'
);

SELECT set_eq(
  format(
    $$select ka.kind, coalesce(ka.professional_id::text, ''), le.direction, le.amount_cents
      from public.kortex_ledger_entries le
      join public.kortex_accounts ka on ka.id = le.account_id
     where le.transaction_id = %L::uuid$$,
    :'transaction_id'
  ),
  format(
    $$values
      ('cash'::text, ''::text, 'debit'::text, 2097::bigint),
      ('revenue_service'::text, ''::text, 'credit'::text, 998::bigint),
      ('revenue_product'::text, ''::text, 'credit'::text, 999::bigint),
      ('tip_liability'::text, ''::text, 'credit'::text, 100::bigint),
      ('commission_expense'::text, ''::text, 'debit'::text, 150::bigint),
      ('staff_current_account'::text, %L::text, 'credit'::text, 100::bigint),
      ('staff_current_account'::text, %L::text, 'credit'::text, 50::bigint)$$,
    :'professional_one', :'professional_two'
  ),
  'journal has exact cash, net revenue, tip and per-professional commission entries'
);
SELECT is(
  (select (coalesce(sum(amount_cents) filter (where direction = 'debit'), 0) - coalesce(sum(amount_cents) filter (where direction = 'credit'), 0))::bigint
     from public.kortex_ledger_entries where transaction_id = :'transaction_id'::uuid),
  0::bigint,
  'checkout journal is balanced'
);
SELECT is(
  (select amount_cents from public.kortex_ledger_entries le join public.kortex_accounts ka on ka.id = le.account_id
    where le.transaction_id = :'transaction_id'::uuid and ka.kind = 'revenue_service'),
  998::bigint,
  'largest-remainder allocation leaves service revenue net of its deterministic share of discount'
);
SELECT is(
  (select amount_cents from public.kortex_ledger_entries le join public.kortex_accounts ka on ka.id = le.account_id
    where le.transaction_id = :'transaction_id'::uuid and ka.kind = 'revenue_product'),
  999::bigint,
  'largest-remainder allocation leaves product revenue net of its deterministic share of discount'
);
SELECT is(
  (select amount_cents from public.kortex_ledger_entries le join public.kortex_accounts ka on ka.id = le.account_id
    where le.transaction_id = :'transaction_id'::uuid and ka.kind = 'tip_liability'),
  100::bigint,
  'tip is a separate liability and does not reduce revenue or commission'
);

SELECT ('o6-ledger:' || encode(digest(
  'checkout-parent-key-001:' || :'order_id' || ':1:closure', 'sha256'
), 'hex')) AS child_key \gset
SELECT is(
  (select key from private.idempotency_keys where organization_id = :'org'::uuid and key = :'child_key'),
  :'child_key',
  'child idempotency key is the deterministic namespaced sha256 derivation'
);
SELECT ok(
  length(:'child_key') < 200 and :'child_key' <> 'checkout-parent-key-001',
  'child idempotency key cannot reuse the parent key and stays within the key limit'
);

SELECT (private.checkout_ledger_post(
  :'org'::uuid, :'owner'::uuid, 'checkout-parent-key-001', :'order_id'::uuid, 1, 'checkout_close'
) ->> 'transaction_id')::uuid AS replay_transaction_id \gset
SELECT is(
  :'replay_transaction_id'::uuid,
  :'transaction_id'::uuid,
  'same parent key and facts replay the cached ledger response'
);

UPDATE public.order_items
SET commission_cents = 101
WHERE organization_id = :'org'::uuid AND order_id = :'order_id'::uuid AND service_id = :'service_one'::uuid;
SELECT throws_ok(
  format(
    'select private.checkout_ledger_post(%L, %L, %L, %L, 1, %L)',
    :'org', :'owner', 'checkout-parent-key-001', :'order_id', 'checkout_close'
  ),
  '22023',
  'idempotency key reused with different payload',
  'same derived child key rejects a journal that diverges from its first payload'
);

-- The refund context is internal too, but its journal must be an exact inverse
-- of the linked closure and use a distinct sub-operation key.
INSERT INTO public.order_revisions (
  organization_id, unit_id, order_id, revision_number, snapshot, closed_by, closed_at
) VALUES (
  :'org'::uuid, :'unit'::uuid, :'order_id'::uuid, 1, '{}'::jsonb, :'owner'::uuid, now()
);
INSERT INTO public.order_ledger_links (
  organization_id, unit_id, order_id, revision_number, ledger_transaction_id, kind
) VALUES (
  :'org'::uuid, :'unit'::uuid, :'order_id'::uuid, 1, :'transaction_id'::uuid, 'closure'
);
SELECT (private.checkout_ledger_post(
  :'org'::uuid, :'owner'::uuid, 'refund-parent-key-002', :'order_id'::uuid, 1, 'order_refund'
) ->> 'transaction_id')::uuid AS reversal_transaction_id \gset
SELECT set_eq(
  format(
    'select account_id, direction, amount_cents from public.kortex_ledger_entries where transaction_id = %L::uuid',
    :'reversal_transaction_id'
  ),
  format(
    $$select account_id,
        case when direction = 'debit' then 'credit' else 'debit' end as direction,
        amount_cents
      from public.kortex_ledger_entries
     where transaction_id = %L::uuid$$,
    :'transaction_id'
  ),
  'authorized order_refund context posts the exact inverse of the linked closure'
);
SELECT ('o6-ledger:' || encode(digest(
  'refund-parent-key-002:' || :'order_id' || ':1:reversal', 'sha256'
), 'hex')) AS reversal_child_key \gset
SELECT ok(
  :'reversal_child_key' <> :'child_key'
    and exists (select 1 from private.idempotency_keys where organization_id = :'org'::uuid and key = :'reversal_child_key'),
  'reversal sub-operation has a distinct deterministic child key'
);

SELECT throws_ok(
  format('select private.checkout_ledger_post(%L, %L, %L, %L, 1, %L)', :'org', :'reception', 'reclose-parent-key-001', :'order_id', 'order_reclose'),
  '42501', NULL,
  'reception cannot invoke the internal order_reclose ledger context'
);
SELECT throws_ok(
  format('select private.checkout_ledger_post(%L, %L, %L, %L, 1, %L)', :'org', :'reception', 'refund-parent-key-001', :'order_id', 'order_refund'),
  '42501', NULL,
  'reception cannot invoke the internal order_refund ledger context'
);
SELECT throws_ok(
  format('select private.checkout_ledger_post(%L, %L, %L, %L, 1, %L)', :'org', :'owner', 'invalid-command-001', :'order_id', 'not_a_command'),
  '22023',
  'unsupported internal ledger command',
  'private checkout ledger accepts only its enumerated Command contexts'
);

SELECT has_function(
  'private',
  'checkout_ledger_post',
  ARRAY['uuid', 'uuid', 'text', 'uuid', 'integer', 'text'],
  'the checkout-only journal primitive exists only in the private schema'
);

SELECT * FROM finish();
ROLLBACK;
