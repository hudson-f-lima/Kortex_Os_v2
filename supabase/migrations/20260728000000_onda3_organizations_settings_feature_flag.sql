-- Onda 3, fatia 017 (issues/017-organizations-settings-feature-flag.md,
-- Blueprint §3.7/§4, DEC-46): fundação de Dark Launching por Feature Flag
-- (DEC-44, otimização 1). Reaproveitável por qualquer Onda futura, não
-- exclusiva da Onda 3 — nenhuma chave é lida por nenhuma rota nesta fatia.

-- Pre-flight check (DEC-44, otimização 2): confere pré-condição antes do
-- DDL em vez de deixar o ALTER TABLE falhar com erro genérico do Postgres.
do $$
begin
  if to_regclass('public.organizations') is null then
    raise exception 'pre-flight check failed: public.organizations does not exist';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'organizations' and column_name = 'settings'
  ) then
    raise exception 'pre-flight check failed: public.organizations.settings already exists';
  end if;
end $$;

alter table public.organizations
  add column settings jsonb not null default '{}'::jsonb;

-- Sem policy nova: organizations_select (is_member) e organizations_update
-- (owner/admin, mvp_baseline.sql) são row-level, não column-level — já
-- cobrem settings como qualquer outra coluna da mesma linha.
