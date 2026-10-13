-- Onda 5, fatia 035 (issues/035-onda5-waitlist-acceptance.md, DEC-51/DEC-52).
-- Implementa
-- docs/waves/onda-5-recurring-group-waitlist/KORTEXOS_5_1_2_BLUEPRINT_ONDA_5.md
-- §3.3.5/§3.3.6/§3.3.7/§3.3.9/§5 — aceitar/recusar/expirar oferta, modelo
-- Booksy (sem hold persistente): a confirmação trava a entrada com CAS
-- (status='OFFERED'), chama create_appointment e resolve tudo em uma única
-- transação.
--
-- Escopo de identidade (achado desta fatia, não do Blueprint): o produto
-- ainda não tem canal de autenticação client-facing (só memberships de
-- staff — mesma lacuna já registrada na fatia 034 para a RLS de
-- waitlist_entries/waitlist_offers). "Validação de identidade por sessão
-- autenticada ou OTP" (§3.3.5) fica para quando esse canal existir; nesta
-- fatia, a posse do token opaco de uso único é o próprio portão de
-- autorização, verificado por hash — suficiente para "URL com entry_id
-- visível não é autorização", independente de quem apresenta o token
-- (staff hoje, canal de cliente no futuro). Mesmo motivo pelo qual esta
-- fatia, como 032/033/034, não constrói contrato Jest/rota Express (issue
-- 035 não pede).

do $$
begin
  if to_regclass('public.waitlist_entries') is null then
    raise exception 'pre-flight failed: public.waitlist_entries does not exist (fatia 034 must run first)';
  end if;
  if to_regclass('public.waitlist_offers') is null then
    raise exception 'pre-flight failed: public.waitlist_offers does not exist (fatia 034 must run first)';
  end if;
  if to_regprocedure('public.create_appointment(uuid,uuid,text,jsonb)') is null then
    raise exception 'pre-flight failed: public.create_appointment does not exist';
  end if;
  if to_regprocedure('public.waitlist_offer_accept(uuid,uuid,text,jsonb)') is not null then
    raise exception 'pre-flight failed: public.waitlist_offer_accept already exists';
  end if;
end $$;

-- ============================================================================
-- waitlist_offer_accept (Blueprint §3.3.5/§3.3.6/§3.3.9/§5). HOLDING nunca é
-- observável fora desta transação: é setado e resolvido (para BOOKED ou
-- desfeito por rollback) sem nenhum commit intermediário.
-- ============================================================================

create or replace function public.waitlist_offer_accept(
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
  v_offer_id uuid := nullif(p_payload ->> 'offer_id', '')::uuid;
  v_token text := p_payload ->> 'token';
  v_offer public.waitlist_offers%rowtype;
  v_entry public.waitlist_entries%rowtype;
  v_create_result jsonb;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner','admin','manager','reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if v_offer_id is null or v_token is null or length(v_token) = 0 then
    raise exception 'offer_id and token are required' using errcode = '22023';
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

  -- CAS (Blueprint §3.3.6): trava a oferta antes de qualquer decisão. Nunca
  -- vaza se o offer_id existe em outro tenant — organization_id erra junto
  -- com o id, então uma oferta de outro tenant simplesmente não é
  -- encontrada (mesma disciplina de toda outra RPC desta trilha).
  select * into v_offer from public.waitlist_offers
  where organization_id = p_organization_id and id = v_offer_id
  for update;
  if not found then
    raise exception 'waitlist offer not found' using errcode = 'P0002';
  end if;

  -- "Vencida" é uma condição de tempo real, não só o status persistido: uma
  -- oferta com expires_at no passado nunca reserva o slot, mesmo que o job
  -- de expiração (waitlist_offer_expire) ainda não tenha rodado.
  if v_offer.status <> 'OFFERED' or v_offer.expires_at <= now() then
    raise exception 'waitlist offer is not open for a decision' using errcode = 'P0023';
  end if;
  if encode(digest(v_token, 'sha256'), 'hex') <> v_offer.token_hash then
    raise exception 'waitlist offer token does not match' using errcode = 'P0024';
  end if;

  select * into v_entry from public.waitlist_entries
  where organization_id = p_organization_id and id = v_offer.waitlist_entry_id
  for update;
  if not found then
    raise exception 'waitlist entry not found' using errcode = 'P0002';
  end if;

  -- HOLDING é puramente transacional (Blueprint §3.3.2): nasce e morre
  -- dentro desta mesma transação, nunca observável após commit.
  update public.waitlist_entries set status = 'HOLDING' where organization_id = p_organization_id and id = v_entry.id;

  v_create_result := public.create_appointment(
    p_organization_id, p_actor_user_id, p_idempotency_key || ':appointment',
    jsonb_build_object(
      'client_id', v_entry.client_id, 'professional_id', v_offer.candidate_professional_id,
      'service_id', v_entry.service_id, 'starts_at', v_offer.candidate_starts_at,
      'origin', 'waitlist', 'unit_id', v_offer.unit_id
    )
  );
  if v_create_result ->> 'status' <> 'applied' then
    raise exception 'waitlist acceptance requires an applied appointment' using errcode = 'P0001';
  end if;

  update public.waitlist_offers set status = 'ACCEPTED', responded_at = now()
  where organization_id = p_organization_id and id = v_offer_id;
  update public.waitlist_entries set status = 'BOOKED'
  where organization_id = p_organization_id and id = v_entry.id;

  -- Ofertas irmãs da mesma onda perdem a corrida (Blueprint §3.3.7): viram
  -- SUPERSEDED e suas entradas voltam para ACTIVE, sujeitas ao cooldown já
  -- calculado quando a oferta foi criada.
  update public.waitlist_entries we set
    status = 'ACTIVE',
    cooldown_until = wo.cooldown_until
  from public.waitlist_offers wo
  where wo.organization_id = p_organization_id and wo.offer_wave_id = v_offer.offer_wave_id
    and wo.id <> v_offer_id and wo.status = 'OFFERED'
    and we.organization_id = p_organization_id and we.id = wo.waitlist_entry_id;

  update public.waitlist_offers
  set status = 'SUPERSEDED', responded_at = now()
  where organization_id = p_organization_id and offer_wave_id = v_offer.offer_wave_id
    and id <> v_offer_id and status = 'OFFERED';

  v_response := jsonb_build_object(
    'status', 'applied', 'appointment', v_create_result -> 'appointment',
    'waitlist_entry_id', v_entry.id, 'offer_id', v_offer_id
  );
  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.waitlist_offer_accept(uuid, uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.waitlist_offer_accept(uuid, uuid, text, jsonb) to service_role;

-- ============================================================================
-- waitlist_offer_decline (Blueprint §3.3.4/§5) — recusa explícita: a
-- entrada volta para ACTIVE com o cooldown já calculado na criação da
-- oferta. Não afeta outras ofertas da mesma onda (só esta entrada recusou;
-- as demais continuam OFFERED até vencerem ou serem superadas).
-- ============================================================================

create or replace function public.waitlist_offer_decline(
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
  v_offer_id uuid := nullif(p_payload ->> 'offer_id', '')::uuid;
  v_token text := p_payload ->> 'token';
  v_offer public.waitlist_offers%rowtype;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner','admin','manager','reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if v_offer_id is null or v_token is null or length(v_token) = 0 then
    raise exception 'offer_id and token are required' using errcode = '22023';
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

  select * into v_offer from public.waitlist_offers
  where organization_id = p_organization_id and id = v_offer_id
  for update;
  if not found then
    raise exception 'waitlist offer not found' using errcode = 'P0002';
  end if;
  if v_offer.status <> 'OFFERED' or v_offer.expires_at <= now() then
    raise exception 'waitlist offer is not open for a decision' using errcode = 'P0023';
  end if;
  if encode(digest(v_token, 'sha256'), 'hex') <> v_offer.token_hash then
    raise exception 'waitlist offer token does not match' using errcode = 'P0024';
  end if;

  update public.waitlist_offers set status = 'DECLINED', responded_at = now()
  where organization_id = p_organization_id and id = v_offer_id;
  update public.waitlist_entries set status = 'ACTIVE', cooldown_until = v_offer.cooldown_until
  where organization_id = p_organization_id and id = v_offer.waitlist_entry_id;

  v_response := jsonb_build_object('status', 'applied', 'offer_id', v_offer_id, 'waitlist_entry_id', v_offer.waitlist_entry_id);
  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.waitlist_offer_decline(uuid, uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.waitlist_offer_decline(uuid, uuid, text, jsonb) to service_role;

-- ============================================================================
-- waitlist_offer_expire (Blueprint §3.3.4/§5) — expira só ofertas
-- realmente vencidas; não cancela appointment porque não há appointment de
-- hold (nunca existiu). Nenhum token exigido: é o caminho de sistema
-- (job periódico), não uma decisão do cliente.
-- ============================================================================

create or replace function public.waitlist_offer_expire(
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
  v_offer_id uuid := nullif(p_payload ->> 'offer_id', '')::uuid;
  v_offer public.waitlist_offers%rowtype;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner','admin','manager','reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if v_offer_id is null then
    raise exception 'offer_id is required' using errcode = '22023';
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

  select * into v_offer from public.waitlist_offers
  where organization_id = p_organization_id and id = v_offer_id
  for update;
  if not found then
    raise exception 'waitlist offer not found' using errcode = 'P0002';
  end if;
  if v_offer.status <> 'OFFERED' or v_offer.expires_at > now() then
    raise exception 'waitlist offer is not open for a decision' using errcode = 'P0023';
  end if;

  update public.waitlist_offers set status = 'EXPIRED', responded_at = now()
  where organization_id = p_organization_id and id = v_offer_id;
  update public.waitlist_entries set status = 'ACTIVE', cooldown_until = v_offer.cooldown_until
  where organization_id = p_organization_id and id = v_offer.waitlist_entry_id;

  v_response := jsonb_build_object('status', 'applied', 'offer_id', v_offer_id, 'waitlist_entry_id', v_offer.waitlist_entry_id);
  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.waitlist_offer_expire(uuid, uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.waitlist_offer_expire(uuid, uuid, text, jsonb) to service_role;
