-- Onda 6, fatia 055 (DEC-62/DEC-66, ADR 0025): fundação imutável para
-- reabertura versionada. Esta primeira iteração materializa somente a
-- revisão corrente do pedido; os demais fatos entram em ciclos TDD próprios.

-- Pre-flight (DEC-44): falha com diagnóstico antes de DDL se a fundação
-- esperada não estiver presente ou se a migration estiver sendo reaplicada.
do $$
begin
  if to_regclass('public.orders') is null then
    raise exception 'pre-flight check failed: public.orders does not exist';
  end if;

  if exists (
    select 1
      from information_schema.columns
     where table_schema = 'public'
       and table_name = 'orders'
       and column_name = 'current_revision'
  ) then
    raise exception 'pre-flight check failed: public.orders.current_revision already exists';
  end if;
end
$$;

alter table public.orders
  add column current_revision integer not null default 1
    constraint orders_current_revision_positive check (current_revision > 0);
