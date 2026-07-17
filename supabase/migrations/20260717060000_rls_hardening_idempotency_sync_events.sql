-- Segurança (achado do advisor scan de produção, 2026-07-17):
-- private.idempotency_keys estava sem RLS habilitado. Não era uma exposição
-- ativa hoje (nem anon nem authenticated têm grant na tabela, e o schema
-- private não é exposto via PostgREST), mas faltava a camada de defesa em
-- profundidade que toda outra tabela do schema public já tem.
alter table private.idempotency_keys enable row level security;

-- Nenhuma policy é adicionada de propósito: esta tabela é bookkeeping interno
-- de idempotência, escrita/lida só pelas RPCs security definer (checkout_close,
-- inventory_adjust, create_appointment, update_appointment, membership_set,
-- create_organization, create_package/update_package) que rodam com o
-- privilégio do dono da função, não do chamador — nunca deve ser consultável
-- direto por anon/authenticated via PostgREST. RLS habilitado + zero policies
-- nega acesso a qualquer role sem BYPASSRLS, mesmo que um grant futuro seja
-- concedido por engano.
comment on table private.idempotency_keys is
  'RLS habilitado deliberadamente sem nenhuma policy: bookkeeping interno de '
  'idempotência, tocado só por RPCs security definer. Nunca deve ficar '
  'consultável direto por anon/authenticated — ver supabase/tests/rls_baseline_test.sql.';

-- public.sync_events já tinha RLS habilitado sem policies (correto desde a
-- migration original) e grant restrito a service_role — o advisor sinalizou
-- isso como "atenção" por não ter uma policy explícita documentando a
-- intenção. Formalizando: este é o estado terminal correto, não uma lacuna.
comment on table public.sync_events is
  'RLS habilitado deliberadamente sem nenhuma policy: o único consumidor '
  'legítimo é o backend via service_role (BYPASSRLS, grant select explícito) — '
  'anon/authenticated nunca devem ler esta tabela direto, sempre pelo endpoint '
  '/sync do Express. Zero policies é o estado terminal correto — ver '
  'supabase/tests/sync_events_test.sql.';
