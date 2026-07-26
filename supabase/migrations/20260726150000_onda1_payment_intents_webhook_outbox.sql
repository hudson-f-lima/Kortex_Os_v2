-- Onda 1, fatia 002 (issues/002-payment-intents-webhook-outbox.md): schema
-- de payment_intents e o outbox mínimo de ingestão de webhook. Ver
-- docs/KORTEXOS_5_1_2_BLUEPRINT_ONDA_1_DRAFT.md §2, §3.4, §3.5, §4.
--
-- Nenhuma integração real com PSP nesta fatia — apenas o schema e a
-- idempotência contra replay (achados #1 e #2 do Red Team, §3.5). Toda
-- escrita continua vindo do backend (service_role, BYPASSRLS); RLS aqui é
-- defesa em profundidade, mesmo padrão do resto do catálogo/fatos.

create table public.payment_intents (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  unit_id uuid not null,
  order_id uuid,
  purpose text not null check (purpose in ('checkout', 'deposit')),
  -- provider/provider_reference: texto livre, agnóstico de fornecedor (§2) —
  -- nunca um enum fechado de PSPs específicos.
  provider text not null check (length(trim(provider)) between 1 and 60),
  provider_reference text not null check (length(trim(provider_reference)) between 1 and 200),
  amount_cents bigint not null check (amount_cents >= 0),
  status text not null default 'requires_capture'
    check (status in ('requires_capture', 'captured', 'canceled', 'failed')),
  -- nullable: o fluxo de webhook não tem ator humano (§4).
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id),
  -- defesa em profundidade contra duas linhas para a mesma transação externa,
  -- independente da unicidade do evento em psp_webhook_events (§3.5).
  unique (organization_id, provider, provider_reference),
  foreign key (organization_id, unit_id) references public.units(organization_id, id),
  foreign key (organization_id, order_id) references public.orders(organization_id, id),
  foreign key (organization_id, created_by) references public.memberships(organization_id, user_id)
);

create index payment_intents_org_unit_idx on public.payment_intents(organization_id, unit_id);

create trigger payment_intents_touch before update on public.payment_intents
  for each row execute function private.touch_updated_at();

alter table public.payment_intents enable row level security;

-- SELECT: owner/admin/manager org-wide; reception/professional escopados à
-- unidade (§3.4) — mesmo helper já usado pelos outros fatos da Onda 0.
-- Nenhum INSERT/UPDATE direto de authenticated/anon: toda escrita é
-- service_role (backend), sem policy alguma para essas operações.
create policy payment_intents_select on public.payment_intents for select to authenticated using (
  private.can_access_fact_unit(
    organization_id,
    unit_id,
    array['owner', 'admin', 'manager'],
    array['reception', 'professional']
  )
);

-- psp_webhook_events: outbox de ingestão. Dado de sistema — nenhuma tela
-- nesta onda, nenhum grant a anon/authenticated (§3.4), mesmo padrão de
-- unit_access_audit_events. organization_id/unit_id/payment_intent_id
-- nascem juntos como NULL (dead-letter) e são preenchidos juntos quando o
-- evento é correspondido a um payment_intent — nunca parcialmente.
create table public.psp_webhook_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid,
  unit_id uuid,
  payment_intent_id uuid,
  provider text not null check (length(trim(provider)) between 1 and 60),
  -- ID do evento do provedor, não o provider_reference do intent (§3.5).
  provider_event_id text not null check (length(trim(provider_event_id)) between 1 and 200),
  event_type text not null check (length(trim(event_type)) between 1 and 120),
  payload jsonb not null,
  processed_at timestamptz,
  retry_count integer not null default 0 check (retry_count >= 0),
  last_error text,
  received_at timestamptz not null default now(),
  unique (provider, provider_event_id),
  check (
    (organization_id is null and unit_id is null and payment_intent_id is null)
    or (organization_id is not null and unit_id is not null and payment_intent_id is not null)
  ),
  foreign key (organization_id, unit_id) references public.units(organization_id, id),
  foreign key (organization_id, payment_intent_id) references public.payment_intents(organization_id, id)
);

create index psp_webhook_events_intent_idx on public.psp_webhook_events(payment_intent_id)
  where payment_intent_id is not null;

alter table public.psp_webhook_events enable row level security;
-- Nenhuma policy: nem owner/admin lê psp_webhook_events pela Data API.
