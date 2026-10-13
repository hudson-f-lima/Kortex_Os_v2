-- Onda 1 remediation, fatia 4.
--
-- Webhook ingestion is one database transaction. A durable dead-letter is
-- retried on every identical delivery until it is linked and processed; a
-- processed event remains an idempotent no-op.

alter table public.psp_webhook_events
  add column provider_reference text;
create index psp_webhook_events_unprocessed_reference_idx
  on public.psp_webhook_events(provider, provider_reference)
  where processed_at is null and provider_reference is not null;

create or replace function public.psp_webhook_event_ingest(
  p_provider text,
  p_provider_event_id text,
  p_event_type text,
  p_provider_reference text,
  p_status text,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_event public.psp_webhook_events%rowtype;
  v_intent public.payment_intents%rowtype;
  v_match_count integer;
begin
  insert into public.psp_webhook_events(
    provider, provider_event_id, event_type, provider_reference, payload
  ) values (
    p_provider, p_provider_event_id, p_event_type, p_provider_reference, p_payload
  )
  on conflict (provider, provider_event_id) do update
  set provider_reference = coalesce(public.psp_webhook_events.provider_reference, excluded.provider_reference),
      event_type = excluded.event_type
  returning * into v_event;

  if v_event.processed_at is not null then
    return jsonb_build_object('duplicate', true, 'matched', true, 'processed', true);
  end if;

  select count(*) into v_match_count
  from public.payment_intents pi
  where pi.provider = p_provider and pi.provider_reference = p_provider_reference;

  if v_match_count <> 1 then
    update public.psp_webhook_events
    set retry_count = retry_count + case when v_event.received_at < now() then 1 else 0 end,
        last_error = case when v_match_count = 0 then 'payment intent not found' else 'ambiguous provider reference across organizations' end
    where id = v_event.id;
    return jsonb_build_object(
      'duplicate', false,
      'matched', false,
      'ambiguous', v_match_count > 1
    );
  end if;

  select * into v_intent
  from public.payment_intents pi
  where pi.provider = p_provider and pi.provider_reference = p_provider_reference
  for update;

  begin
    update public.payment_intents
    set status = p_status
    where id = v_intent.id;

    -- A provider's explicit authorization-expired event can close only a
    -- still-active card authorization. It can never overwrite captured,
    -- released or immediate-charge holds.
    if p_event_type = 'payment_intent.authorization_expired'
      and v_intent.purpose = 'deposit'
    then
      update public.deposit_holds
      set status = 'expired'
      where organization_id = v_intent.organization_id
        and payment_intent_id = v_intent.id
        and mechanic = 'hold'
        and status = 'active';
    end if;

    update public.psp_webhook_events
    set organization_id = v_intent.organization_id,
        unit_id = v_intent.unit_id,
        payment_intent_id = v_intent.id,
        processed_at = now(),
        last_error = null
    where id = v_event.id;
  exception when others then
    update public.psp_webhook_events
    set retry_count = retry_count + 1,
        last_error = left(sqlerrm, 1000)
    where id = v_event.id;
    return jsonb_build_object('duplicate', false, 'matched', false, 'processed', false, 'retryable', true);
  end;

  return jsonb_build_object('duplicate', false, 'matched', true, 'processed', true);
end;
$$;

create or replace function public.psp_webhook_event_reprocess(
  p_event_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_event public.psp_webhook_events%rowtype;
  v_status text;
begin
  select * into v_event
  from public.psp_webhook_events
  where id = p_event_id
  for update;
  if not found then
    raise exception 'webhook event not found' using errcode = 'P0014';
  end if;
  if v_event.provider_reference is null then
    raise exception 'webhook event has no normalized provider reference to reprocess' using errcode = 'P0014';
  end if;
  v_status := v_event.payload ->> 'status';
  if v_status is null then
    raise exception 'webhook event has no provider status to reprocess' using errcode = 'P0014';
  end if;
  return public.psp_webhook_event_ingest(
    v_event.provider,
    v_event.provider_event_id,
    v_event.event_type,
    v_event.provider_reference,
    v_status,
    v_event.payload
  );
end;
$$;

revoke all on function public.psp_webhook_event_ingest(text, text, text, text, text, jsonb) from public, anon, authenticated;
grant execute on function public.psp_webhook_event_ingest(text, text, text, text, text, jsonb) to service_role;
revoke all on function public.psp_webhook_event_reprocess(uuid) from public, anon, authenticated;
grant execute on function public.psp_webhook_event_reprocess(uuid) to service_role;
