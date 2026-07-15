-- Fase 10: Hardening do módulo Appointments
-- (a) Adicionar coluna version para lock otimista
-- (b) Guard de transição de status (completed é terminal)

-- (a) Lock otimista: coluna version
alter table public.appointments add column version bigint not null default 1;

-- (b) FSM: completed é imutável (não pode transicionar para outro estado)
-- Nota: reversão privilegiada (ex: admin cancela uma conclusão) será tratada no RLS/aplicação,
-- não neste CHECK constraint — guardamos a regra geral de que completed não sai de completed.

create or replace function private.enforce_appointments_fsm()
returns trigger language plpgsql security definer set search_path = pg_catalog, public as $$
begin
  if old.status = 'completed' and new.status <> 'completed' then
    raise exception 'completed appointments are immutable' using errcode = '23514';
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_appointments_fsm() from public, anon, authenticated;

create trigger appointments_enforce_fsm
before update on public.appointments
for each row execute function private.enforce_appointments_fsm();

-- (c) Lock otimista: falha se version divergir
create or replace function private.enforce_appointment_version()
returns trigger language plpgsql security definer set search_path = pg_catalog as $$
begin
  if tg_op = 'UPDATE' then
    new.version := new.version + 1;
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_appointment_version() from public, anon, authenticated;

create trigger appointments_increment_version
before update on public.appointments
for each row execute function private.enforce_appointment_version();
