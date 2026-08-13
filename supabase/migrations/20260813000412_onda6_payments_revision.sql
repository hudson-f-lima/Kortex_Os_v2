-- Onda 6, fatia 055 (DEC-62/DEC-66, ADR 0025): pagamentos append-only por
-- revisão. Migration separada porque a anterior já foi aplicada localmente.
do $$
begin
  if to_regclass('public.payments') is null then
    raise exception 'pre-flight check failed: public.payments does not exist';
  end if;

  if exists (
    select 1
      from information_schema.columns
     where table_schema = 'public'
       and table_name = 'payments'
       and column_name = 'revision_number'
  ) then
    raise exception 'pre-flight check failed: public.payments.revision_number already exists';
  end if;
end
$$;

alter table public.payments
  add column revision_number integer not null default 1
    constraint payments_revision_number_positive check (revision_number > 0);
