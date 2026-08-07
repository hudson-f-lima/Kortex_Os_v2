-- Onda 5, fatia 039 (DEC-54/DEC-55, ADR-0023).
-- AppCliente: auth.uid() e o vínculo server-owned ao clients.id são a
-- autorização primária; a capacidade opaca da oferta é obrigatória em
-- complemento. O outbox FCM é transacional: nenhum worker observa a oferta
-- antes do commit que a criou.

do $$
begin
  if to_regclass('public.waitlist_offers') is null
     or to_regclass('public.waitlist_entries') is null
     or to_regclass('public.clients') is null then
    raise exception 'onda5 fatia039 requires waitlist and clients tables';
  end if;
  if to_regprocedure('public.create_appointment(uuid,uuid,text,jsonb)') is null then
    raise exception 'onda5 fatia039 requires canonical create_appointment';
  end if;
end;
$$;

create table public.client_app_identities (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  client_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (organization_id, client_id),
  unique (organization_id, user_id),
  unique (organization_id, client_id, user_id),
  foreign key (organization_id, client_id)
    references public.clients(organization_id, id) on delete cascade
);

alter table public.appointments
  add column client_booking_user_id uuid references auth.users(id);
alter table public.appointments
  add constraint appointments_client_booking_identity_fkey
  foreign key (organization_id, client_id, client_booking_user_id)
  references public.client_app_identities(organization_id, client_id, user_id);

create table public.client_push_devices (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  client_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  fcm_token text not null check (length(fcm_token) between 1 and 4096),
  platform text not null check (platform in ('android', 'ios', 'web')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, fcm_token),
  foreign key (organization_id, client_id)
    references public.client_app_identities(organization_id, client_id) on delete cascade,
  foreign key (organization_id, user_id)
    references public.client_app_identities(organization_id, user_id) on delete cascade
);
create index client_push_devices_identity_idx
  on public.client_push_devices(organization_id, client_id, user_id);
create trigger client_push_devices_touch
before update on public.client_push_devices
for each row execute function private.touch_updated_at();

create table private.waitlist_offer_push_outbox (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  offer_id uuid not null references public.waitlist_offers(id) on delete cascade,
  client_id uuid not null,
  client_user_id uuid not null references auth.users(id) on delete cascade,
  device_id uuid not null references public.client_push_devices(id) on delete cascade,
  payload jsonb not null,
  delivered_at timestamptz,
  failed_at timestamptz,
  failure_reason text,
  created_at timestamptz not null default now(),
  unique (offer_id, device_id),
  foreign key (organization_id, client_id)
    references public.client_app_identities(organization_id, client_id) on delete cascade,
  foreign key (organization_id, client_user_id)
    references public.client_app_identities(organization_id, user_id) on delete cascade
);
create index waitlist_offer_push_outbox_pending_idx
  on private.waitlist_offer_push_outbox(created_at)
  where delivered_at is null and failed_at is null;

-- A trigger histórico usa auth.uid() para impedir spoofing de created_by.
-- Nesta única rota security-definer o JWT é do cliente, enquanto o ator
-- operacional já foi resolvido no servidor. O marcador é local à transação,
-- limitado a INSERT de appointments e não abre DML direto (RLS/grants seguem
-- fechados para o AppCliente).
create or replace function private.enforce_created_by()
returns trigger language plpgsql set search_path = pg_catalog as $$
declare
  v_user_id uuid := (select auth.uid());
  v_preserve_appointment_actor boolean :=
    tg_table_name = 'appointments'
    and current_setting('app.kortex.waitlist_client_booking', true) = 'on';
begin
  if tg_op = 'INSERT' and v_user_id is not null and not v_preserve_appointment_actor then
    new.created_by := v_user_id;
  elsif tg_op = 'INSERT' and new.created_by is null then
    raise exception 'created_by is required' using errcode = '23502';
  elsif new.created_by <> old.created_by then
    raise exception 'created_by is immutable' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function private.enforce_created_by() from public, anon, authenticated;

alter table public.client_app_identities enable row level security;
alter table public.client_push_devices enable row level security;

create policy client_app_identities_select_self
on public.client_app_identities for select to authenticated
using (user_id = (select auth.uid()));

create policy client_push_devices_select_self
on public.client_push_devices for select to authenticated
using (user_id = (select auth.uid()));

create policy client_push_devices_insert_self
on public.client_push_devices for insert to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.client_app_identities cai
    where cai.organization_id = client_push_devices.organization_id
      and cai.client_id = client_push_devices.client_id
      and cai.user_id = (select auth.uid())
  )
);

create policy client_push_devices_update_self
on public.client_push_devices for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy client_push_devices_delete_self
on public.client_push_devices for delete to authenticated
using (user_id = (select auth.uid()));

create or replace function private.client_app_identity_for_auth(
  p_organization_id uuid,
  p_user_id uuid
) returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_client_id uuid;
begin
  if p_user_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select client_id into v_client_id
  from public.client_app_identities
  where organization_id = p_organization_id and user_id = p_user_id;
  if not found then
    raise exception 'client identity not found' using errcode = '42501';
  end if;
  return v_client_id;
end;
$$;
revoke all on function private.client_app_identity_for_auth(uuid, uuid) from public, anon, authenticated, service_role;

create or replace function public.client_push_device_register(
  p_organization_id uuid,
  p_fcm_token text,
  p_platform text
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_user_id uuid := auth.uid();
  v_client_id uuid;
  v_existing public.client_push_devices%rowtype;
  v_device_id uuid;
begin
  if p_organization_id is null or p_fcm_token is null or length(p_fcm_token) not between 1 and 4096
     or p_platform not in ('android', 'ios', 'web') then
    raise exception 'invalid client push device payload' using errcode = '22023';
  end if;
  v_client_id := private.client_app_identity_for_auth(p_organization_id, v_user_id);

  select * into v_existing
  from public.client_push_devices
  where organization_id = p_organization_id and fcm_token = p_fcm_token
  for update;
  if found and (v_existing.user_id <> v_user_id or v_existing.client_id <> v_client_id) then
    raise exception 'push device is already registered to another client' using errcode = '42501';
  end if;

  if found then
    update public.client_push_devices
    set platform = p_platform
    where id = v_existing.id
    returning id into v_device_id;
  else
    insert into public.client_push_devices(organization_id, client_id, user_id, fcm_token, platform)
    values (p_organization_id, v_client_id, v_user_id, p_fcm_token, p_platform)
    returning id into v_device_id;
  end if;
  return jsonb_build_object('status', 'applied', 'device_id', v_device_id);
end;
$$;

create or replace function public.client_waitlist_offer_inbox(
  p_organization_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_user_id uuid := auth.uid();
  v_client_id uuid;
  v_offer record;
  v_token text;
  v_offers jsonb := '[]'::jsonb;
begin
  v_client_id := private.client_app_identity_for_auth(p_organization_id, v_user_id);
  for v_offer in
    select wo.id, wo.candidate_starts_at, wo.candidate_ends_at,
           wo.candidate_professional_id, wo.expires_at, we.service_id
    from public.waitlist_offers wo
    join public.waitlist_entries we
      on we.organization_id = wo.organization_id and we.id = wo.waitlist_entry_id
    where wo.organization_id = p_organization_id
      and we.client_id = v_client_id
      and wo.status = 'OFFERED'
      and wo.expires_at > now()
    order by wo.expires_at, wo.created_at
    for update of wo
  loop
    -- O fallback não persiste capacidade legível: cada abertura autenticada
    -- reemite um token e invalida o anterior, mantendo o hash no banco.
    v_token := encode(gen_random_bytes(32), 'hex');
    update public.waitlist_offers
    set token_hash = encode(digest(v_token, 'sha256'), 'hex')
    where id = v_offer.id and organization_id = p_organization_id;
    v_offers := v_offers || jsonb_build_array(jsonb_build_object(
      'offer_id', v_offer.id,
      'service_id', v_offer.service_id,
      'professional_id', v_offer.candidate_professional_id,
      'starts_at', v_offer.candidate_starts_at,
      'ends_at', v_offer.candidate_ends_at,
      'expires_at', v_offer.expires_at,
      'token', v_token
    ));
  end loop;
  return jsonb_build_object('status', 'applied', 'offers', v_offers);
end;
$$;

create or replace function public.waitlist_offer_accept_client(
  p_offer_id uuid,
  p_idempotency_key text,
  p_token text
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_user_id uuid := auth.uid();
  v_hash text := encode(digest(jsonb_build_object('offer_id', p_offer_id, 'token', p_token)::text, 'sha256'), 'hex');
  v_offer public.waitlist_offers%rowtype;
  v_entry public.waitlist_entries%rowtype;
  v_existing private.idempotency_keys%rowtype;
  v_booking_actor uuid;
  v_create_result jsonb;
  v_response jsonb;
begin
  if v_user_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_offer_id is null or p_token is null or length(p_token) = 0
     or p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid client offer acceptance payload' using errcode = '22023';
  end if;

  -- A própria busca é vinculada ao auth.uid(); outro cliente e outro tenant
  -- recebem o mesmo not-found sem oracle de existência da oferta.
  select wo.* into v_offer
  from public.waitlist_offers wo
  join public.waitlist_entries we
    on we.organization_id = wo.organization_id and we.id = wo.waitlist_entry_id
  join public.client_app_identities cai
    on cai.organization_id = wo.organization_id
   and cai.client_id = we.client_id
   and cai.user_id = v_user_id
  where wo.id = p_offer_id
  for update of wo;
  if not found then
    raise exception 'waitlist offer not found' using errcode = 'P0002';
  end if;
  if v_offer.status <> 'OFFERED' or v_offer.expires_at <= now() then
    raise exception 'waitlist offer is not open for a decision' using errcode = 'P0023';
  end if;
  if encode(digest(p_token, 'sha256'), 'hex') <> v_offer.token_hash then
    raise exception 'waitlist offer token does not match' using errcode = 'P0024';
  end if;

  insert into private.idempotency_keys(organization_id, key, request_hash, created_by)
  values (v_offer.organization_id, p_idempotency_key, v_hash, v_user_id)
  on conflict (organization_id, key) do nothing;
  select * into v_existing from private.idempotency_keys
  where organization_id = v_offer.organization_id and key = p_idempotency_key
  for update;
  if v_existing.request_hash <> v_hash then
    raise exception 'idempotency key reused with different payload' using errcode = '22023';
  end if;
  if v_existing.response is not null then return v_existing.response; end if;

  select * into v_entry from public.waitlist_entries
  where organization_id = v_offer.organization_id and id = v_offer.waitlist_entry_id
  for update;
  if not found then
    raise exception 'waitlist entry not found' using errcode = 'P0002';
  end if;
  update public.waitlist_entries set status = 'HOLDING'
  where organization_id = v_offer.organization_id and id = v_entry.id;

  -- A RPC canônica permanece dona de elegibilidade, calendário e exclusão de
  -- agenda. Ela exige ator staff; selecionamos um ator de sistema pertencente
  -- ao tenant. `created_by` permanece uma membership (invariante histórico);
  -- a autoria client-facing fica em client_booking_user_id, amarrada ao mesmo
  -- cliente no tenant por FK composta.
  select m.user_id into v_booking_actor
  from public.memberships m
  where m.organization_id = v_offer.organization_id and m.active
    and m.role in ('owner', 'admin', 'manager', 'reception')
  order by case m.role when 'owner' then 1 when 'admin' then 2 when 'manager' then 3 else 4 end
  limit 1;
  if v_booking_actor is null then
    raise exception 'organization has no booking actor' using errcode = 'P0001';
  end if;
  perform set_config('app.kortex.waitlist_client_booking', 'on', true);
  v_create_result := public.create_appointment(
    v_offer.organization_id, v_booking_actor, p_idempotency_key || ':appointment',
    jsonb_build_object(
      'client_id', v_entry.client_id, 'professional_id', v_offer.candidate_professional_id,
      'service_id', v_entry.service_id, 'starts_at', v_offer.candidate_starts_at,
      'origin', 'waitlist', 'unit_id', v_offer.unit_id
    )
  );
  if v_create_result ->> 'status' <> 'applied' then
    raise exception 'waitlist acceptance requires an applied appointment' using errcode = 'P0001';
  end if;
  update public.appointments
  set client_booking_user_id = v_user_id
  where organization_id = v_offer.organization_id
    and id = (v_create_result -> 'appointment' ->> 'id')::uuid;

  update public.waitlist_offers set status = 'ACCEPTED', responded_at = now()
  where organization_id = v_offer.organization_id and id = v_offer.id;
  update public.waitlist_entries set status = 'BOOKED'
  where organization_id = v_offer.organization_id and id = v_entry.id;
  update public.waitlist_entries we set status = 'ACTIVE', cooldown_until = wo.cooldown_until
  from public.waitlist_offers wo
  where wo.organization_id = v_offer.organization_id and wo.offer_wave_id = v_offer.offer_wave_id
    and wo.id <> v_offer.id and wo.status = 'OFFERED'
    and we.organization_id = v_offer.organization_id and we.id = wo.waitlist_entry_id;
  update public.waitlist_offers set status = 'SUPERSEDED', responded_at = now()
  where organization_id = v_offer.organization_id and offer_wave_id = v_offer.offer_wave_id
    and id <> v_offer.id and status = 'OFFERED';

  v_response := jsonb_build_object(
    'status', 'applied', 'appointment', v_create_result -> 'appointment',
    'waitlist_entry_id', v_entry.id, 'offer_id', v_offer.id
  );
  update private.idempotency_keys set response = v_response
  where organization_id = v_offer.organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;

revoke all on table public.client_app_identities, public.client_push_devices from public, anon, authenticated;
revoke all on table private.waitlist_offer_push_outbox from public, anon, authenticated;
revoke all on function public.client_push_device_register(uuid, text, text) from public, anon;
revoke all on function public.client_waitlist_offer_inbox(uuid) from public, anon;
revoke all on function public.waitlist_offer_accept_client(uuid, text, text) from public, anon;
grant execute on function public.client_push_device_register(uuid, text, text) to authenticated;
grant execute on function public.client_waitlist_offer_inbox(uuid) to authenticated;
grant execute on function public.waitlist_offer_accept_client(uuid, text, text) to authenticated;
