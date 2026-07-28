-- Onda 3, fatia 018 (issues/018-staff-levels-professional-assignment.md,
-- Blueprint §2/§3.1/§3.8/§4, DEC-46): cadastro de staff_levels (nível de
-- carreira por organização, org-wide, sem unit_id) e o ponteiro
-- professionals.staff_level_id (nullable, sem tabela de vigência temporal —
-- "promoção não retroage" já é garantido pelo snapshot no momento da
-- confirmação, ADR 0011). Fundação sem ativação: nenhuma cascata de
-- preço/tempo/comissão nasce aqui (fatia 019).
--
-- Desvio de produto registrado, não silencioso (Blueprint §3.1, aprovado
-- via DEC-46): o Master Briefing §6.1 declara nível "Obrigatório", mas
-- staff_level_id nasce nullable porque staff_levels nasce vazia por
-- organização — não há nível nenhum pra apontar até o owner cadastrar um.
-- A obrigatoriedade real vira regra de ativação (validação de aplicação
-- quando a organização ligar staff_levels_enabled), não CHECK de banco.

-- Pre-flight check (DEC-44, otimização 2).
do $$
begin
  if to_regclass('public.organizations') is null then
    raise exception 'pre-flight check failed: public.organizations does not exist';
  end if;
  if to_regclass('public.professionals') is null then
    raise exception 'pre-flight check failed: public.professionals does not exist';
  end if;
  if to_regclass('public.staff_levels') is not null then
    raise exception 'pre-flight check failed: public.staff_levels already exists';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'professionals' and column_name = 'staff_level_id'
  ) then
    raise exception 'pre-flight check failed: public.professionals.staff_level_id already exists';
  end if;
end $$;

create table public.staff_levels (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  name text not null check (length(trim(name)) between 1 and 80),
  rank integer not null check (rank >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id),
  unique (organization_id, name),
  unique (organization_id, rank)
);

create trigger staff_levels_touch before update on public.staff_levels for each row execute function private.touch_updated_at();

alter table public.staff_levels enable row level security;

-- Cadastro operacional, mesmo padrão de services/service_groups (Blueprint §3.8).
create policy staff_levels_select on public.staff_levels for select to authenticated using (private.is_member(organization_id));
create policy staff_levels_insert on public.staff_levels for insert to authenticated with check (private.has_role(organization_id, array['owner','admin','manager']));
create policy staff_levels_update on public.staff_levels for update to authenticated using (private.has_role(organization_id, array['owner','admin','manager'])) with check (private.has_role(organization_id, array['owner','admin','manager']));
create policy staff_levels_delete on public.staff_levels for delete to authenticated using (private.has_role(organization_id, array['owner','admin']));

-- professionals.staff_level_id: ponteiro simples, nullable, on delete restrict
-- (não é possível apagar um nível ainda referenciado por um profissional).
alter table public.professionals
  add column staff_level_id uuid,
  add constraint professionals_staff_level_fk foreign key (organization_id, staff_level_id) references public.staff_levels(organization_id, id) on delete restrict;
