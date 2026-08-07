-- Onda 5, fatia 034 (issues/034-onda5-waitlist-matching.md, DEC-51/DEC-52).
-- Implementa
-- docs/waves/onda-5-recurring-group-waitlist/KORTEXOS_5_1_2_BLUEPRINT_ONDA_5.md
-- §3.3/§4.6/§4.7 — waitlist_entries, waitlist_entry_professionals,
-- waitlist_offers e o matcher idempotente (modelo Booksy: notificação sem
-- hold, primeiro que confirmar vence). Esta fatia cria e oferta; aceitar/
-- recusar/expirar a oferta (CAS, token de uso único, create_appointment em
-- transação única) é escopo da fatia 035, que ainda não existe.
--
-- Igual a issues/032/033, issues/034 não pede contrato Jest/rota Express —
-- só SQL+pgTAP (mesma leitura literal do Aceite escrito, sem expandir
-- escopo).
--
-- waitlist_entries.status usa só ACTIVE e OFFERED nesta fatia. MATCHED,
-- HOLDING, BOOKED, DECLINED, EXPIRED e SUPPRESSED são estados válidos do
-- enum sem produtor aqui: HOLDING/BOOKED/DECLINED/EXPIRED nascem em
-- waitlist_offer_accept/_decline/_expire (fatia 035, que também devolve a
-- entrada a ACTIVE conforme §3.3.4); MATCHED e SUPPRESSED ficam reservados
-- para evolução futura (ex.: notificação assíncrona em duas fases, supressão
-- manual por staff), sem uso nesta fatia — mesmo padrão de DRAFT em
-- appointment_groups (fatia 032).

do $$
begin
  if to_regclass('public.appointments') is null then
    raise exception 'pre-flight failed: public.appointments does not exist';
  end if;
  if to_regclass('public.professional_units') is null then
    raise exception 'pre-flight failed: public.professional_units does not exist';
  end if;
  if to_regprocedure('private.onda5_waitlist_settings(uuid)') is null then
    raise exception 'pre-flight failed: private.onda5_waitlist_settings does not exist (fatia 029 must run first)';
  end if;
  if to_regprocedure('private.onda5_range_within_blocks(jsonb,integer,integer)') is null then
    raise exception 'pre-flight failed: private.onda5_range_within_blocks does not exist';
  end if;
  if to_regprocedure('private.resolve_calendar_policy(uuid,uuid,date)') is null then
    raise exception 'pre-flight failed: private.resolve_calendar_policy does not exist';
  end if;
  if to_regprocedure('private.resolve_professional_shift(uuid,uuid,uuid,date)') is null then
    raise exception 'pre-flight failed: private.resolve_professional_shift does not exist';
  end if;
  if to_regprocedure('private.resolve_calendar_overrides(uuid,uuid,uuid,date)') is null then
    raise exception 'pre-flight failed: private.resolve_calendar_overrides does not exist';
  end if;
  if to_regclass('public.waitlist_entries') is not null then
    raise exception 'pre-flight failed: public.waitlist_entries already exists';
  end if;
end $$;

-- ============================================================================
-- 1. waitlist_entries (Blueprint §4.6)
-- ============================================================================

create table public.waitlist_entries (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  unit_id uuid not null,
  client_id uuid not null,
  service_id uuid not null,
  date_from date not null,
  date_to date not null,
  status text not null default 'ACTIVE' check (status in (
    'ACTIVE', 'MATCHED', 'OFFERED', 'HOLDING', 'BOOKED', 'DECLINED', 'EXPIRED', 'SUPPRESSED'
  )),
  consent_at timestamptz not null,
  last_offered_at timestamptz,
  cooldown_until timestamptz,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (date_to >= date_from),
  unique (organization_id, id, unit_id),
  foreign key (organization_id, unit_id) references public.units(organization_id, id) on delete restrict,
  foreign key (organization_id, client_id) references public.clients(organization_id, id),
  foreign key (organization_id, service_id) references public.services(organization_id, id)
);

create index waitlist_entries_active_lookup_idx
  on public.waitlist_entries(organization_id, unit_id, service_id, status)
  where status = 'ACTIVE';

create trigger waitlist_entries_touch before update on public.waitlist_entries
  for each row execute function private.touch_updated_at();

alter table public.waitlist_entries enable row level security;

-- Leitura: can_access_fact_unit (staff). O canal de cliente ("a própria
-- entrada", Blueprint §7) fica de fora — este produto não tem ainda um
-- mecanismo de autenticação client-facing (só memberships de staff); não
-- há policy para inventar sem esse contexto real.
create policy waitlist_entries_select on public.waitlist_entries for select to authenticated using (
  private.can_access_fact_unit(
    organization_id, unit_id,
    array['owner', 'admin'],
    array['manager', 'reception', 'professional']
  )
);
-- Escrita: nenhum grant direto a authenticated — só via waitlist_entry_create
-- e o matcher (abaixo), security definer.

-- ============================================================================
-- 2. waitlist_entry_professionals (Blueprint §4.6) — zero linhas = qualquer
--    profissional elegível.
-- ============================================================================

create table public.waitlist_entry_professionals (
  organization_id uuid not null,
  unit_id uuid not null,
  waitlist_entry_id uuid not null,
  professional_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (organization_id, waitlist_entry_id, professional_id),
  foreign key (organization_id, waitlist_entry_id, unit_id)
    references public.waitlist_entries(organization_id, id, unit_id) on delete restrict,
  foreign key (organization_id, professional_id, unit_id)
    references public.professional_units(organization_id, professional_id, unit_id) on delete restrict
);

alter table public.waitlist_entry_professionals enable row level security;

create policy waitlist_entry_professionals_select on public.waitlist_entry_professionals for select to authenticated using (
  private.can_access_fact_unit(
    organization_id, unit_id,
    array['owner', 'admin'],
    array['manager', 'reception', 'professional']
  )
);
-- Escrita: nenhum grant direto — só via waitlist_entry_create.

-- ============================================================================
-- 3. waitlist_offers (Blueprint §4.7) — token_hash é o único registro do
--    token; o token bruto nunca é persistido, só devolvido na resposta da
--    RPC de matching (para o outbox/KortexLink notificar o cliente).
-- ============================================================================

create table public.waitlist_offers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  unit_id uuid not null,
  waitlist_entry_id uuid not null,
  offer_wave_id uuid not null,
  candidate_starts_at timestamptz not null,
  candidate_ends_at timestamptz not null,
  candidate_professional_id uuid not null,
  status text not null default 'OFFERED' check (status in ('OFFERED', 'ACCEPTED', 'DECLINED', 'EXPIRED', 'SUPERSEDED')),
  token_hash text not null,
  expires_at timestamptz not null,
  cooldown_until timestamptz not null,
  idempotency_key text not null check (length(idempotency_key) between 8 and 200),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (candidate_ends_at > candidate_starts_at),
  unique (organization_id, id, unit_id),
  unique (organization_id, idempotency_key),
  foreign key (organization_id, unit_id) references public.units(organization_id, id) on delete restrict,
  foreign key (organization_id, waitlist_entry_id, unit_id)
    references public.waitlist_entries(organization_id, id, unit_id) on delete restrict,
  foreign key (organization_id, candidate_professional_id, unit_id)
    references public.professional_units(organization_id, professional_id, unit_id) on delete restrict
);

-- Idempotência do matcher (Blueprint §3.3.8): a mesma entrada nunca recebe
-- duas ofertas ABERTAS para o mesmo slot+profissional, mesmo entre chamadas
-- com idempotency_key diferentes (ex.: dois triggers de cancelamento
-- concorrentes apontando pro mesmo slot liberado).
create unique index waitlist_offers_open_slot_idx
  on public.waitlist_offers(organization_id, waitlist_entry_id, candidate_starts_at, candidate_professional_id)
  where status = 'OFFERED';
create index waitlist_offers_wave_idx on public.waitlist_offers(organization_id, offer_wave_id);
create index waitlist_offers_expiring_idx on public.waitlist_offers(organization_id, status, expires_at) where status = 'OFFERED';

alter table public.waitlist_offers enable row level security;

-- Leitura: staff da unidade. O canal de cliente ("oferta cujo token/
-- identidade foi validado", Blueprint §7) é resolvido pela fatia 035
-- (aceitar/recusar exigem o token, não list/select direto).
create policy waitlist_offers_select on public.waitlist_offers for select to authenticated using (
  private.can_access_fact_unit(
    organization_id, unit_id,
    array['owner', 'admin'],
    array['manager', 'reception', 'professional']
  )
);
-- Escrita: nenhum grant direto — só o matcher cria; aceitar/recusar/expirar
-- (fatia 035) são as únicas RPCs que podem mudar o status depois.

-- ============================================================================
-- 4. waitlist_entry_create (Blueprint §5) — consentimento explícito
--    obrigatório (consent_at só é gravado quando o payload afirma
--    consent=true), preferências de profissional opcionais e validadas
--    contra o vínculo profissional↔unidade real.
-- ============================================================================

create or replace function public.waitlist_entry_create(
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
  v_unit_id uuid := nullif(p_payload ->> 'unit_id', '')::uuid;
  v_client_id uuid := nullif(p_payload ->> 'client_id', '')::uuid;
  v_service_id uuid := nullif(p_payload ->> 'service_id', '')::uuid;
  v_date_from date := nullif(p_payload ->> 'date_from', '')::date;
  v_date_to date := nullif(p_payload ->> 'date_to', '')::date;
  v_consent boolean := (p_payload ->> 'consent')::boolean;
  v_professional_ids uuid[];
  v_professional_id uuid;
  v_entry_id uuid := gen_random_uuid();
  v_entry_json jsonb;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner','admin','manager','reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if v_unit_id is null or v_client_id is null or v_service_id is null or v_date_from is null or v_date_to is null then
    raise exception 'unit_id, client_id, service_id, date_from and date_to are required' using errcode = '22023';
  end if;
  if v_date_to < v_date_from then
    raise exception 'date_to must not be before date_from' using errcode = '22023';
  end if;
  if coalesce(v_consent, false) is not true then
    raise exception 'explicit consent is required to join the waitlist' using errcode = '22023';
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

  if not exists (select 1 from public.units where organization_id = p_organization_id and id = v_unit_id) then
    raise exception 'unit not found' using errcode = 'P0002';
  end if;
  if not exists (select 1 from public.clients where organization_id = p_organization_id and id = v_client_id) then
    raise exception 'client not found' using errcode = 'P0002';
  end if;
  if not exists (select 1 from public.services where organization_id = p_organization_id and id = v_service_id) then
    raise exception 'service not found' using errcode = 'P0002';
  end if;

  select array_agg(x::uuid) into v_professional_ids
  from jsonb_array_elements_text(coalesce(p_payload -> 'professional_ids', '[]'::jsonb)) x;

  if v_professional_ids is not null then
    foreach v_professional_id in array v_professional_ids loop
      if not exists (
        select 1 from public.professional_units
        where organization_id = p_organization_id and unit_id = v_unit_id
          and professional_id = v_professional_id and active
      ) then
        raise exception 'professional is not linked to this unit' using errcode = 'P0002';
      end if;
    end loop;
  end if;

  insert into public.waitlist_entries(id, organization_id, unit_id, client_id, service_id, date_from, date_to, consent_at)
  values (v_entry_id, p_organization_id, v_unit_id, v_client_id, v_service_id, v_date_from, v_date_to, now());

  if v_professional_ids is not null and array_length(v_professional_ids, 1) > 0 then
    insert into public.waitlist_entry_professionals(organization_id, unit_id, waitlist_entry_id, professional_id)
    select p_organization_id, v_unit_id, v_entry_id, x from unnest(v_professional_ids) x;
  end if;

  select jsonb_build_object(
    'id', we.id, 'organization_id', we.organization_id, 'unit_id', we.unit_id, 'client_id', we.client_id,
    'service_id', we.service_id, 'date_from', we.date_from, 'date_to', we.date_to, 'status', we.status
  ) into v_entry_json
  from public.waitlist_entries we where we.id = v_entry_id;

  v_response := jsonb_build_object('status', 'applied', 'entry', v_entry_json);
  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.waitlist_entry_create(uuid, uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.waitlist_entry_create(uuid, uuid, text, jsonb) to service_role;

-- ============================================================================
-- 5. waitlist_matcher_run (Blueprint §3.3.1/§3.3.3/§3.3.8/§5) — o matcher
--    nomeado nesta Etapa 8. Recebe um slot exato já liberado (unit_id,
--    professional_id, service_id, starts_at — tipicamente disparado por um
--    cancelamento), roda o Availability Resolver uma vez para o próprio
--    slot (mesma disciplina de create_appointment/origin<>'direct') e cria
--    uma onda de ofertas simultâneas para toda entrada ACTIVE elegível.
--    Idempotente em duas camadas: idempotency_keys para replay exato da
--    mesma chamada, e o índice único parcial em waitlist_offers para
--    impedir duas ofertas abertas do mesmo slot para a mesma entrada mesmo
--    sob chamadas concorrentes com chaves diferentes.
-- ============================================================================

create or replace function public.waitlist_matcher_run(
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
  v_unit_id uuid := nullif(p_payload ->> 'unit_id', '')::uuid;
  v_professional_id uuid := nullif(p_payload ->> 'professional_id', '')::uuid;
  v_service_id uuid := nullif(p_payload ->> 'service_id', '')::uuid;
  v_starts_at timestamptz := (p_payload ->> 'starts_at')::timestamptz;
  v_timezone text;
  v_local_date date;
  v_start_minutes integer;
  v_end_minutes integer;
  v_override_open boolean;
  v_override_reason text;
  v_policy_blocks jsonb;
  v_shift_blocks jsonb;
  v_eligible boolean;
  v_duration integer;
  v_ends_at timestamptz;
  v_ttl_minutes integer;
  v_cooldown_hours integer;
  v_offer_wave_id uuid := gen_random_uuid();
  v_entry record;
  v_token text;
  v_token_hash text;
  v_offer_id uuid;
  v_offers jsonb := '[]'::jsonb;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner','admin','manager','reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if v_unit_id is null or v_professional_id is null or v_service_id is null or v_starts_at is null then
    raise exception 'unit_id, professional_id, service_id and starts_at are required' using errcode = '22023';
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

  if not exists (select 1 from public.units where organization_id = p_organization_id and id = v_unit_id) then
    raise exception 'unit not found' using errcode = 'P0002';
  end if;
  if not exists (select 1 from public.professionals where organization_id = p_organization_id and id = v_professional_id) then
    raise exception 'professional not found' using errcode = 'P0002';
  end if;
  if not exists (select 1 from public.services where organization_id = p_organization_id and id = v_service_id) then
    raise exception 'service not found' using errcode = 'P0002';
  end if;
  if not exists (
    select 1 from public.professional_units
    where organization_id = p_organization_id and unit_id = v_unit_id and professional_id = v_professional_id and active
  ) then
    raise exception 'professional is not linked to this unit' using errcode = 'P0002';
  end if;

  select r.eligible into v_eligible from private.resolve_eligibility(p_organization_id, v_professional_id, v_service_id) r;
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

  select timezone into v_timezone from public.units where organization_id = p_organization_id and id = v_unit_id;
  v_local_date := (v_starts_at at time zone v_timezone)::date;
  v_start_minutes := extract(hour from (v_starts_at at time zone v_timezone))::int * 60
    + extract(minute from (v_starts_at at time zone v_timezone))::int;
  v_end_minutes := extract(hour from (v_ends_at at time zone v_timezone))::int * 60
    + extract(minute from (v_ends_at at time zone v_timezone))::int;
  if v_end_minutes <= v_start_minutes then
    raise exception 'candidate slot cannot cross local midnight' using errcode = '22023';
  end if;

  select o.is_open, o.reason into v_override_open, v_override_reason
  from private.resolve_calendar_overrides(p_organization_id, v_unit_id, v_professional_id, v_local_date) o;
  if v_override_open is not null and v_override_open = false then
    raise exception 'slot outside calendar availability (%)', v_override_reason using errcode = 'P0006';
  end if;
  select p.blocks into v_policy_blocks from private.resolve_calendar_policy(p_organization_id, v_unit_id, v_local_date) p;
  if not private.onda5_range_within_blocks(v_policy_blocks, v_start_minutes, v_end_minutes) then
    raise exception 'slot outside unit calendar policy' using errcode = 'P0006';
  end if;
  select s.blocks into v_shift_blocks from private.resolve_professional_shift(p_organization_id, v_professional_id, v_unit_id, v_local_date) s;
  if not private.onda5_range_within_blocks(v_shift_blocks, v_start_minutes, v_end_minutes) then
    raise exception 'slot outside professional shift' using errcode = 'P0006';
  end if;

  -- Lê organizations.settings diretamente, com o mesmo coalesce/defaults de
  -- private.onda5_waitlist_settings (fatia 029) — não chama essa função
  -- aqui. Achado do Red Team de implementação: onda5_waitlist_settings usa
  -- private.is_member(), que deriva o membro da sessão JWT autenticada
  -- (request.jwt.claim.sub) para checar tenant mesmo sendo security
  -- definer — desenho correto para uma chamada direta de cliente
  -- autenticado via PostgREST, mas o matcher já validou o actor
  -- explicitamente por private.actor_has_role(p_actor_user_id, ...) acima;
  -- não há sessão JWT alguma quando esta função é chamada internamente
  -- (service_role, sem auth.uid()), então is_member sempre falharia aqui,
  -- mesmo com o actor certo.
  select
    coalesce((o.settings ->> 'waitlist_offer_ttl_minutes')::integer, 30),
    coalesce((o.settings ->> 'waitlist_offer_cooldown_hours')::integer, 6)
    into v_ttl_minutes, v_cooldown_hours
  from public.organizations o
  where o.id = p_organization_id;

  for v_entry in
    select we.* from public.waitlist_entries we
    where we.organization_id = p_organization_id
      and we.unit_id = v_unit_id
      and we.service_id = v_service_id
      and we.status = 'ACTIVE'
      and we.date_from <= v_local_date and we.date_to >= v_local_date
      and (we.cooldown_until is null or we.cooldown_until <= now())
      and (
        not exists (
          select 1 from public.waitlist_entry_professionals wep
          where wep.organization_id = p_organization_id and wep.waitlist_entry_id = we.id
        )
        or exists (
          select 1 from public.waitlist_entry_professionals wep
          where wep.organization_id = p_organization_id and wep.waitlist_entry_id = we.id
            and wep.professional_id = v_professional_id
        )
      )
    order by we.created_at
    for update
  loop
    v_token := encode(gen_random_bytes(32), 'hex');
    v_token_hash := encode(digest(v_token, 'sha256'), 'hex');
    v_offer_id := gen_random_uuid();

    insert into public.waitlist_offers(
      id, organization_id, unit_id, waitlist_entry_id, offer_wave_id,
      candidate_starts_at, candidate_ends_at, candidate_professional_id,
      token_hash, expires_at, cooldown_until, idempotency_key
    ) values (
      v_offer_id, p_organization_id, v_unit_id, v_entry.id, v_offer_wave_id,
      v_starts_at, v_ends_at, v_professional_id,
      v_token_hash, now() + (v_ttl_minutes || ' minutes')::interval,
      now() + (v_cooldown_hours || ' hours')::interval,
      p_idempotency_key || ':entry:' || v_entry.id::text
    )
    on conflict (organization_id, waitlist_entry_id, candidate_starts_at, candidate_professional_id)
      where status = 'OFFERED'
    do nothing;

    if found then
      update public.waitlist_entries
      set status = 'OFFERED', last_offered_at = now(), attempt_count = attempt_count + 1
      where organization_id = p_organization_id and id = v_entry.id;

      v_offers := v_offers || jsonb_build_array(jsonb_build_object(
        'id', v_offer_id, 'waitlist_entry_id', v_entry.id, 'offer_wave_id', v_offer_wave_id,
        'candidate_starts_at', v_starts_at, 'candidate_ends_at', v_ends_at,
        'candidate_professional_id', v_professional_id,
        'expires_at', now() + (v_ttl_minutes || ' minutes')::interval,
        'token', v_token
      ));
    end if;
  end loop;

  v_response := jsonb_build_object('status', 'applied', 'offer_wave_id', v_offer_wave_id, 'offers', v_offers);
  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.waitlist_matcher_run(uuid, uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.waitlist_matcher_run(uuid, uuid, text, jsonb) to service_role;
