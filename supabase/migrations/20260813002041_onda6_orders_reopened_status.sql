-- Onda 6, fatia 055: fecha o enum/check do pedido vivo antes de qualquer
-- Command poder transicionar closed -> reopened. A migration anterior de
-- Fase 9 removeu o check composto historico, portanto este guard e explicito.
do $$
begin
  if to_regclass('public.orders') is null then
    raise exception 'pre-flight check failed: public.orders does not exist';
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.orders'::regclass
      and conname = 'orders_status_check'
  ) then
    raise exception 'pre-flight check failed: public.orders_status_check is required';
  end if;

  if exists (
    select 1
    from public.orders
    where status not in ('draft', 'closed', 'reopened', 'cancelled', 'refunded')
  ) then
    raise exception 'pre-flight check failed: public.orders contains an unsupported status';
  end if;
end
$$;

alter table public.orders
  drop constraint orders_status_check;

alter table public.orders
  add constraint orders_status_check
    check (status in ('draft', 'closed', 'reopened', 'cancelled', 'refunded'));
