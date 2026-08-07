-- Onda 5, fatia 033 (issues/033-onda5-participants.md, DEC-51/DEC-52).
-- Implementa
-- docs/waves/onda-5-recurring-group-waitlist/KORTEXOS_5_1_2_BLUEPRINT_ONDA_5.md
-- §3.2.7/§4.5 — appointment_participants como fonte única de presença,
-- trigger de titular, backfill idempotente e RPC de participante. Também
-- endurece o invariante "titular imutável" (§3.1.9/§4.2) diretamente em
-- update_appointment, decisão que a fatia 030 deliberadamente adiou para
-- esta fatia (ver comentário de 20260804020000).
--
-- Ordem de execução em relação à fatia 032 (achado desta sessão, não do
-- Blueprint §6 original, que já previa "trigger + backfill... criar
-- appointment_groups" nesta ordem): appointment_groups (fatia 032) depende
-- deste trigger para que cada filho do grupo ganhe automaticamente sua
-- linha de titular — por isso 033 é aplicada antes de 032, mesmo com
-- numeração de issue posterior.
--
-- Escape hatch controlado para "titular imutável": update_appointment ganha
-- um 6º parâmetro posicional opcional (p_allow_client_transfer, default
-- false) — não uma chave dentro do jsonb, que um corpo HTTP poderia
-- carregar sem querer. Só appointment_replan_with_hold (o único comando
-- aprovado de transferência explícita, Onda 1 remediação 3b) passa `true`;
-- nenhum chamador HTTP genérico (PATCH /appointments/:id) pode alcançá-lo,
-- porque o Express nunca aceita client_id nesse contrato (ver
-- backend/src/modules/appointments/appointments.validation.js, mesma
-- alteração desta fatia). Quando a transferência é permitida e o cliente
-- realmente muda, a linha de titular em appointment_participants migra
-- junto, na mesma transação — sem isso, "todo appointment possui titular"
-- quebraria depois do primeiro replan.

do $$
begin
  if to_regclass('public.appointments') is null then
    raise exception 'pre-flight failed: public.appointments does not exist';
  end if;
  if to_regclass('public.appointment_series') is null then
    raise exception 'pre-flight failed: public.appointment_series does not exist';
  end if;
  if to_regprocedure('public.update_appointment(uuid,uuid,text,uuid,jsonb)') is null then
    raise exception 'pre-flight failed: public.update_appointment(5 args) does not exist';
  end if;
  if to_regprocedure('public.appointment_replan_with_hold(uuid,uuid,text,uuid,jsonb)') is null then
    raise exception 'pre-flight failed: public.appointment_replan_with_hold does not exist';
  end if;
  if not exists (select 1 from pg_constraint where conname = 'appointments_org_id_unit_unique') then
    raise exception 'pre-flight failed: appointments_org_id_unit_unique does not exist';
  end if;
  if to_regclass('public.appointment_participants') is not null then
    raise exception 'pre-flight failed: public.appointment_participants already exists';
  end if;
end $$;

-- ============================================================================
-- 1. appointment_participants (Blueprint §4.5)
-- ============================================================================

create table public.appointment_participants (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  unit_id uuid not null,
  appointment_id uuid not null,
  client_id uuid not null,
  role text not null check (role in ('payer', 'beneficiary', 'payer_beneficiary')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, appointment_id, client_id),
  foreign key (organization_id, unit_id) references public.units(organization_id, id) on delete restrict,
  -- cascade, não restrict: uma linha de participante é dependente puro do
  -- appointment (existe só por causa dele, sem sentido próprio) — diferente
  -- de appointment_series_conflicts, que aponta para trás como histórico e
  -- por isso trava a exclusão. Achado do Red Team de implementação: sem
  -- cascade aqui, o DELETE de fixture já usado por
  -- onda5_appointment_series_create_test.sql (Behavior 4, libera um slot
  -- colidido para o retry) passa a violar esta FK.
  foreign key (organization_id, appointment_id, unit_id)
    references public.appointments(organization_id, id, unit_id) on delete cascade,
  foreign key (organization_id, client_id) references public.clients(organization_id, id)
);

create index appointment_participants_unit_idx on public.appointment_participants(organization_id, unit_id);
create index appointment_participants_appointment_idx on public.appointment_participants(organization_id, appointment_id);

create trigger appointment_participants_touch before update on public.appointment_participants
  for each row execute function private.touch_updated_at();

alter table public.appointment_participants enable row level security;

-- Leitura: mesmo padrão unit-aware das demais tabelas desta Onda (não usa
-- somente is_member — vazaria entre unidades da mesma organização).
create policy appointment_participants_select on public.appointment_participants for select to authenticated using (
  private.can_access_fact_unit(
    organization_id, unit_id,
    array['owner', 'admin'],
    array['manager', 'reception', 'professional']
  )
);
-- Escrita: nenhum grant direto a authenticated — só via o trigger de
-- titular (abaixo) e a RPC appointment_participant_add (security definer).

-- ============================================================================
-- 2. Trigger de titular (Blueprint §4.5) — toda criação de appointment, de
--    qualquer origem (direct/series/group/waitlist), ganha automaticamente
--    sua linha de titular com role='payer_beneficiary'. ON CONFLICT DO
--    NOTHING é defesa em profundidade (a unicidade por
--    (organization_id, appointment_id, client_id) já impediria duplicata),
--    não expectativa de uso normal — um AFTER INSERT roda exatamente uma
--    vez por inserção real.
-- ============================================================================

create or replace function private.onda5_create_titleholder_participant()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  insert into public.appointment_participants(organization_id, unit_id, appointment_id, client_id, role)
  values (new.organization_id, new.unit_id, new.id, new.client_id, 'payer_beneficiary')
  on conflict (organization_id, appointment_id, client_id) do nothing;
  return new;
end;
$$;
revoke all on function private.onda5_create_titleholder_participant() from public, anon, authenticated;

create trigger appointments_create_titleholder_participant
  after insert on public.appointments
  for each row execute function private.onda5_create_titleholder_participant();

-- ============================================================================
-- 3. Backfill idempotente (Blueprint §4.5) — todo appointment já existente
--    (de qualquer fase anterior ao trigger) ganha sua linha de titular.
--    Seguro em retry: NOT EXISTS + ON CONFLICT DO NOTHING tornam uma
--    segunda execução desta migration um no-op completo.
-- ============================================================================

insert into public.appointment_participants(organization_id, unit_id, appointment_id, client_id, role)
select a.organization_id, a.unit_id, a.id, a.client_id, 'payer_beneficiary'
from public.appointments a
where not exists (
  select 1 from public.appointment_participants ap
  where ap.organization_id = a.organization_id and ap.appointment_id = a.id and ap.client_id = a.client_id
)
on conflict (organization_id, appointment_id, client_id) do nothing;

-- ============================================================================
-- 4. update_appointment (extensão) — Blueprint §3.1.9/§4.2. Todo chamador
--    com 5 argumentos continua funcionando sem mudança de comportamento
--    (p_allow_client_transfer tem default false). Rejeita client_id em
--    qualquer chamada que não passe explicitamente `true` — só
--    appointment_replan_with_hold (abaixo) o faz. Quando a transferência é
--    permitida e o cliente muda de fato, a linha de titular em
--    appointment_participants migra na mesma transação.
--
--    A assinatura de 5 argumentos precisa ser derrubada antes: `create or
--    replace` só substitui uma função de MESMA assinatura — com um
--    argumento novo, ele cria um segundo overload ao lado do antigo, e toda
--    chamada com 5 argumentos passa a ser ambígua entre "a função antiga,
--    exata" e "a nova, usando o default" (erro 42725, function is not
--    unique). Achado do Red Team de implementação: isto quebrou
--    appointment_series_update, appointment_group_update/_cancel e vários
--    testes pgTAP pré-existentes antes de ser corrigido.
-- ============================================================================

drop function if exists public.update_appointment(uuid, uuid, text, uuid, jsonb);

create or replace function public.update_appointment(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_idempotency_key text,
  p_appointment_id uuid,
  p_payload jsonb,
  p_allow_client_transfer boolean default false
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_user_id uuid := p_actor_user_id;
  v_hash text := encode(digest(p_payload::text, 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_current public.appointments%rowtype;
  v_touches_config boolean;
  v_client_id uuid;
  v_professional_id uuid;
  v_service_id uuid;
  v_starts_at timestamptz;
  v_status text;
  v_confirm boolean := coalesce((p_payload ->> 'confirm')::boolean, false);
  v_eligible boolean;
  v_source text;
  v_duration integer;
  v_ends_at timestamptz;
  v_response jsonb;
  v_appt_json jsonb;
begin
  if not private.actor_has_role(p_organization_id, v_user_id, array['owner','admin','manager','reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;

  insert into private.idempotency_keys(organization_id, key, request_hash, created_by)
  values (p_organization_id, p_idempotency_key, v_hash, v_user_id)
  on conflict (organization_id, key) do nothing;
  select * into v_existing from private.idempotency_keys
  where organization_id = p_organization_id and key = p_idempotency_key
  for update;
  if v_existing.request_hash <> v_hash then
    raise exception 'idempotency key reused with different payload' using errcode = '22023';
  end if;
  if v_existing.response is not null then return v_existing.response; end if;

  select * into v_current from public.appointments
  where organization_id = p_organization_id and id = p_appointment_id
  for update;
  if not found then raise exception 'appointment not found' using errcode = 'P0005'; end if;

  if not (p_payload ? 'version') or (p_payload ->> 'version') is null then
    raise exception 'version is required' using errcode = '22023';
  end if;
  if v_current.version <> (p_payload ->> 'version')::bigint then
    raise exception 'appointment version conflict' using errcode = 'P0004';
  end if;

  -- Titular imutável (Blueprint §3.1.9/§4.2): fora do comando explícito de
  -- replan, client_id nunca muda. appointment_replan_with_hold é o único
  -- chamador que passa p_allow_client_transfer=true; nenhum contrato HTTP
  -- genérico consegue, porque o Express nunca repassa client_id ao update
  -- comum (defesa em profundidade, mesmo padrão de appointment_series_update).
  if p_payload ? 'client_id' and not p_allow_client_transfer then
    raise exception 'appointment titleholder (client_id) is immutable outside the explicit replan command' using errcode = 'P0022';
  end if;

  v_client_id := case when p_payload ? 'client_id' then (p_payload ->> 'client_id')::uuid else v_current.client_id end;
  v_professional_id := case when p_payload ? 'professional_id' then (p_payload ->> 'professional_id')::uuid else v_current.professional_id end;
  v_service_id := case when p_payload ? 'service_id' then (p_payload ->> 'service_id')::uuid else v_current.service_id end;
  v_starts_at := case when p_payload ? 'starts_at' then (p_payload ->> 'starts_at')::timestamptz else v_current.starts_at end;
  v_status := case when p_payload ? 'status' then p_payload ->> 'status' else v_current.status end;
  v_touches_config := (p_payload ? 'professional_id') or (p_payload ? 'service_id');

  if p_payload ? 'client_id' and not exists (
    select 1 from public.clients where organization_id = p_organization_id and id = v_client_id
  ) then
    raise exception 'client not found' using errcode = 'P0002';
  end if;
  if v_touches_config and not exists (
    select 1 from public.professionals where organization_id = p_organization_id and id = v_professional_id
  ) then
    raise exception 'professional not found' using errcode = 'P0002';
  end if;
  if v_touches_config and not exists (
    select 1 from public.services where organization_id = p_organization_id and id = v_service_id
  ) then
    raise exception 'service not found' using errcode = 'P0002';
  end if;

  if v_touches_config then
    -- Reconfiguração real (profissional e/ou serviço mudou): re-resolve do zero.
    select r.eligible, r.source into v_eligible, v_source
    from private.resolve_eligibility(p_organization_id, v_professional_id, v_service_id) r;
    if not v_eligible then
      raise exception 'professional is not eligible for this service' using errcode = 'P0003';
    end if;

    select coalesce(psc.duration_override_minutes, s.duration_minutes) into v_duration
    from public.services s
    left join public.professional_service_capabilities psc
      on psc.organization_id = p_organization_id
     and psc.professional_id = v_professional_id
     and psc.service_id = v_service_id
    where s.organization_id = p_organization_id and s.id = v_service_id;

    v_ends_at := v_starts_at + (v_duration || ' minutes')::interval;

    if not v_confirm then
      -- ADR 0013: Change Plan — mostra o diff, não aplica. Não persiste
      -- resposta de idempotência: é uma leitura, sem mutação, livre para
      -- ser recalculada em qualquer retry com a mesma chave.
      return jsonb_build_object(
        'status', 'confirmation_required',
        'diff', jsonb_build_object(
          'current', jsonb_build_object(
            'professional_id', v_current.professional_id, 'service_id', v_current.service_id,
            'starts_at', v_current.starts_at, 'ends_at', v_current.ends_at,
            'resolved_duration_minutes', v_current.resolved_duration_minutes,
            'resolved_eligibility_source', v_current.resolved_eligibility_source
          ),
          'proposed', jsonb_build_object(
            'professional_id', v_professional_id, 'service_id', v_service_id,
            'starts_at', v_starts_at, 'ends_at', v_ends_at,
            'resolved_duration_minutes', v_duration,
            'resolved_eligibility_source', v_source
          )
        )
      );
    end if;
  else
    -- MOVE_TIME_ONLY (ADR 0011): preserva a duração/origem já congeladas.
    v_duration := v_current.resolved_duration_minutes;
    v_source := v_current.resolved_eligibility_source;
    v_ends_at := v_starts_at + (v_duration || ' minutes')::interval;
  end if;

  update public.appointments set
    client_id = v_client_id,
    professional_id = v_professional_id,
    service_id = v_service_id,
    starts_at = v_starts_at,
    ends_at = v_ends_at,
    status = v_status,
    resolved_duration_minutes = v_duration,
    resolved_eligibility_source = v_source,
    resolved_at = case when v_touches_config then now() else resolved_at end
  where organization_id = p_organization_id and id = p_appointment_id;

  -- A linha de titular em appointment_participants acompanha a única
  -- transferência aprovada (replan). Sem isto, "todo appointment possui
  -- titular" quebraria assim que o cliente do appointment mudasse.
  if p_allow_client_transfer and p_payload ? 'client_id' and v_client_id <> v_current.client_id then
    delete from public.appointment_participants
    where organization_id = p_organization_id and appointment_id = p_appointment_id and client_id = v_current.client_id;
    insert into public.appointment_participants(organization_id, unit_id, appointment_id, client_id, role)
    values (p_organization_id, v_current.unit_id, p_appointment_id, v_client_id, 'payer_beneficiary')
    on conflict (organization_id, appointment_id, client_id) do update set role = 'payer_beneficiary';
  end if;

  select jsonb_build_object(
    'id', a.id, 'organization_id', a.organization_id, 'client_id', a.client_id, 'professional_id', a.professional_id,
    'service_id', a.service_id, 'starts_at', a.starts_at, 'ends_at', a.ends_at,
    'status', a.status, 'version', a.version,
    'resolved_duration_minutes', a.resolved_duration_minutes,
    'resolved_eligibility_source', a.resolved_eligibility_source,
    'resolved_at', a.resolved_at, 'created_at', a.created_at, 'updated_at', a.updated_at
  ) into v_appt_json
  from public.appointments a
  where a.organization_id = p_organization_id and a.id = p_appointment_id;

  v_response := jsonb_build_object('status', 'applied', 'appointment', v_appt_json);
  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.update_appointment(uuid, uuid, text, uuid, jsonb, boolean) from public, anon, authenticated;
grant execute on function public.update_appointment(uuid, uuid, text, uuid, jsonb, boolean) to service_role;

-- ============================================================================
-- 5. appointment_replan_with_hold (extensão) — único chamador autorizado a
--    passar p_allow_client_transfer=true. Assinatura pública inalterada.
-- ============================================================================

create or replace function public.appointment_replan_with_hold(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_idempotency_key text,
  p_appointment_id uuid,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_hash text := encode(digest(p_payload::text, 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_hold public.deposit_holds%rowtype;
  v_update_result jsonb;
  v_hold_result jsonb;
  v_response jsonb;
  v_internal_key text := 'replan:' || encode(digest(p_idempotency_key, 'sha256'), 'hex');
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner', 'admin', 'manager', 'reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;

  insert into private.idempotency_keys(organization_id, key, request_hash, created_by)
  values (p_organization_id, p_idempotency_key, v_hash, p_actor_user_id)
  on conflict (organization_id, key) do nothing;
  select * into v_existing
  from private.idempotency_keys
  where organization_id = p_organization_id and key = p_idempotency_key
  for update;
  if v_existing.request_hash <> v_hash then
    raise exception 'idempotency key reused with different payload' using errcode = '22023';
  end if;
  if v_existing.response is not null then
    return v_existing.response;
  end if;

  perform 1
  from public.appointments
  where organization_id = p_organization_id and id = p_appointment_id
  for update;
  if not found then
    raise exception 'appointment not found' using errcode = 'P0005';
  end if;

  select * into v_hold
  from public.deposit_holds
  where organization_id = p_organization_id
    and appointment_id = p_appointment_id
    and status = 'active'
  for update;
  if not found then
    raise exception 'replan requires an active deposit hold' using errcode = 'P0013';
  end if;
  if v_hold.mechanic = 'immediate_charge' then
    raise exception 'immediate_charge replan requires a real refund command' using errcode = 'P0008';
  end if;

  update public.deposit_holds
  set status = 'released'
  where id = v_hold.id and status = 'active';
  update public.payment_intents
  set status = 'canceled'
  where id = v_hold.payment_intent_id and status = 'requires_capture';

  v_update_result := public.update_appointment(
    p_organization_id,
    p_actor_user_id,
    v_internal_key,
    p_appointment_id,
    p_payload,
    true
  );
  if v_update_result ->> 'status' <> 'applied' then
    raise exception 'replan requires an applied appointment update' using errcode = 'P0001';
  end if;

  v_hold_result := public.deposit_hold_create(
    p_organization_id,
    p_actor_user_id,
    p_appointment_id
  );
  v_response := jsonb_build_object(
    'status', 'applied',
    'appointment', v_update_result -> 'appointment',
    'released_hold_id', v_hold.id,
    'deposit_hold', case when v_hold_result ->> 'status' = 'created' then v_hold_result -> 'deposit_hold' else null end
  );
  update private.idempotency_keys
  set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.appointment_replan_with_hold(uuid, uuid, text, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.appointment_replan_with_hold(uuid, uuid, text, uuid, jsonb) to service_role;

-- ============================================================================
-- 6. appointment_participant_add (Blueprint §5) — adiciona/atualiza um
--    participante não-titular. A linha do titular (client_id = appointments.
--    client_id) nunca é rebaixada para outra role por esta RPC: ela sempre
--    força 'payer_beneficiary' quando o client_id endereçado é o do titular
--    (Blueprint §4.5, "titular sempre nasce com linha própria").
-- ============================================================================

create or replace function public.appointment_participant_add(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_idempotency_key text,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_hash text := encode(digest(p_payload::text, 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_appointment_id uuid := nullif(p_payload ->> 'appointment_id', '')::uuid;
  v_client_id uuid := nullif(p_payload ->> 'client_id', '')::uuid;
  v_role text := p_payload ->> 'role';
  v_appointment public.appointments%rowtype;
  v_participant public.appointment_participants%rowtype;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner','admin','manager','reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if v_appointment_id is null or v_client_id is null or v_role is null
    or v_role not in ('payer', 'beneficiary', 'payer_beneficiary')
  then
    raise exception 'appointment_id, client_id and a valid role (payer, beneficiary or payer_beneficiary) are required' using errcode = '22023';
  end if;

  insert into private.idempotency_keys(organization_id, key, request_hash, created_by)
  values (p_organization_id, p_idempotency_key, v_hash, p_actor_user_id)
  on conflict (organization_id, key) do nothing;
  select * into v_existing from private.idempotency_keys
  where organization_id = p_organization_id and key = p_idempotency_key
  for update;
  if v_existing.request_hash <> v_hash then
    raise exception 'idempotency key reused with different payload' using errcode = '22023';
  end if;
  if v_existing.response is not null then return v_existing.response; end if;

  select * into v_appointment from public.appointments
  where organization_id = p_organization_id and id = v_appointment_id
  for update;
  if not found then
    raise exception 'appointment not found' using errcode = 'P0005';
  end if;

  if not exists (select 1 from public.clients where organization_id = p_organization_id and id = v_client_id) then
    raise exception 'client not found' using errcode = 'P0002';
  end if;

  if v_client_id = v_appointment.client_id then
    v_role := 'payer_beneficiary';
  end if;

  insert into public.appointment_participants(organization_id, unit_id, appointment_id, client_id, role)
  values (p_organization_id, v_appointment.unit_id, v_appointment_id, v_client_id, v_role)
  on conflict (organization_id, appointment_id, client_id) do update set role = excluded.role
  returning * into v_participant;

  v_response := jsonb_build_object('status', 'applied', 'participant', jsonb_build_object(
    'id', v_participant.id, 'organization_id', v_participant.organization_id, 'unit_id', v_participant.unit_id,
    'appointment_id', v_participant.appointment_id, 'client_id', v_participant.client_id, 'role', v_participant.role
  ));
  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.appointment_participant_add(uuid, uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.appointment_participant_add(uuid, uuid, text, jsonb) to service_role;
