-- Onda 1, fatia 003 (issues/003-deposit-holds-creation.md): schema de
-- deposit_holds e a RPC de criação de hold no fluxo de agendamento. Ver
-- docs/KORTEXOS_5_1_2_BLUEPRINT_ONDA_1_DRAFT.md §2, §3.3, §4, §7.1.
--
-- Aditiva por construção: RPC nova (deposit_hold_create), create_appointment
-- não é modificada. amount_cents/no_show_commission_type/value são
-- snapshotados da política do serviço no momento da criação (mesmo padrão
-- de congelamento da ADR 0011) — mudança posterior na política do serviço
-- não afeta holds já criados.

create table public.deposit_holds (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  unit_id uuid not null,
  appointment_id uuid not null,
  payment_intent_id uuid not null,
  mechanic text not null check (mechanic in ('hold', 'immediate_charge')),
  amount_cents bigint not null check (amount_cents >= 0),
  -- snapshot, independente do commission_type/value normal do serviço (§2.1).
  no_show_commission_type text check (no_show_commission_type in ('percentage', 'fixed')),
  no_show_commission_value bigint check (no_show_commission_value >= 0),
  status text not null default 'active'
    check (status in ('active', 'captured_checkout', 'captured_no_show', 'released', 'expired')),
  -- janela de autorização da rede de cartão, só se aplica a mechanic = 'hold'
  -- (§3.3) — immediate_charge já moveu o dinheiro, não expira.
  expires_at timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id),
  check (
    (no_show_commission_type is null and no_show_commission_value is null)
    or (no_show_commission_type is not null and no_show_commission_value is not null)
  ),
  check (
    (mechanic = 'hold' and expires_at is not null)
    or (mechanic = 'immediate_charge' and expires_at is null)
  ),
  foreign key (organization_id, unit_id) references public.units(organization_id, id),
  foreign key (organization_id, appointment_id) references public.appointments(organization_id, id),
  foreign key (organization_id, payment_intent_id) references public.payment_intents(organization_id, id)
);

-- Exatamente um hold ativo por agendamento (§3.3), mesmo padrão do
-- units_one_default_active_idx da Onda 0.
create unique index deposit_holds_one_active_per_appointment_idx
  on public.deposit_holds(organization_id, appointment_id) where status = 'active';

create index deposit_holds_org_unit_idx on public.deposit_holds(organization_id, unit_id);

create trigger deposit_holds_touch before update on public.deposit_holds
  for each row execute function private.touch_updated_at();

alter table public.deposit_holds enable row level security;

-- SELECT: mesmo padrão can_access_fact_unit de payment_intents (§3.4).
-- Nenhum INSERT/UPDATE direto: toda escrita passa por RPC SECURITY DEFINER,
-- sempre CAS WHERE status = 'active' nas capturas futuras (fatias 4/5).
create policy deposit_holds_select on public.deposit_holds for select to authenticated using (
  private.can_access_fact_unit(
    organization_id,
    unit_id,
    array['owner', 'admin', 'manager'],
    array['reception', 'professional']
  )
);

-- Cria o payment_intent (purpose = 'deposit') e o deposit_hold vinculados a
-- um appointment já existente, só quando o serviço do agendamento tem
-- deposit_mechanic configurado (fatia 001) — caso contrário é um no-op
-- (status = 'skipped'), nunca um erro: a grande maioria dos agendamentos não
-- tem política de depósito.
--
-- provider = 'internal'/provider_reference gerada localmente: esta onda não
-- integra de fato com nenhum PSP (§1, Etapa 9 futura) — o intent nasce
-- pronto para ser substituído por um dispatch real quando essa integração
-- existir, sem mudar o contrato desta RPC.
create or replace function public.deposit_hold_create(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_appointment_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_appointment public.appointments%rowtype;
  v_service public.services%rowtype;
  v_amount_cents bigint;
  v_expires_at timestamptz;
  v_payment_intent_id uuid := gen_random_uuid();
  v_provider_reference text := gen_random_uuid()::text;
  v_deposit_hold_id uuid := gen_random_uuid();
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner', 'admin', 'manager', 'reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;

  select * into v_appointment from public.appointments
  where organization_id = p_organization_id and id = p_appointment_id;
  if not found then
    raise exception 'appointment not found' using errcode = 'P0005';
  end if;

  select * into v_service from public.services
  where organization_id = p_organization_id and id = v_appointment.service_id;

  if v_service.deposit_mechanic is null then
    return jsonb_build_object('status', 'skipped');
  end if;

  if v_service.deposit_type is null or v_service.deposit_value is null then
    raise exception 'service deposit policy is incomplete: deposit_mechanic requires deposit_type and deposit_value'
      using errcode = 'P0006';
  end if;

  v_amount_cents := case when v_service.deposit_type = 'percentage'
    then round(v_service.price_cents * v_service.deposit_value / 10000.0)::bigint
    else v_service.deposit_value end;

  v_expires_at := case when v_service.deposit_mechanic = 'hold' then now() + interval '5 days' else null end;

  insert into public.payment_intents(
    id, organization_id, unit_id, order_id, purpose, provider, provider_reference, amount_cents, status, created_by
  ) values (
    v_payment_intent_id, p_organization_id, v_appointment.unit_id, null, 'deposit', 'internal', v_provider_reference,
    v_amount_cents, 'requires_capture', p_actor_user_id
  );

  insert into public.deposit_holds(
    id, organization_id, unit_id, appointment_id, payment_intent_id, mechanic, amount_cents,
    no_show_commission_type, no_show_commission_value, status, expires_at, created_by
  ) values (
    v_deposit_hold_id, p_organization_id, v_appointment.unit_id, p_appointment_id, v_payment_intent_id,
    v_service.deposit_mechanic, v_amount_cents, v_service.no_show_commission_type, v_service.no_show_commission_value,
    'active', v_expires_at, p_actor_user_id
  );

  select jsonb_build_object(
    'id', dh.id, 'appointment_id', dh.appointment_id, 'payment_intent_id', dh.payment_intent_id,
    'mechanic', dh.mechanic, 'amount_cents', dh.amount_cents,
    'no_show_commission_type', dh.no_show_commission_type, 'no_show_commission_value', dh.no_show_commission_value,
    'status', dh.status, 'expires_at', dh.expires_at, 'created_at', dh.created_at
  ) into v_response
  from public.deposit_holds dh
  where dh.id = v_deposit_hold_id;

  return jsonb_build_object('status', 'created', 'deposit_hold', v_response);
end;
$$;
revoke all on function public.deposit_hold_create(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.deposit_hold_create(uuid, uuid, uuid) to service_role;
