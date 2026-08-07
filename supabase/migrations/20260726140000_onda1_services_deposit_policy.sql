-- Onda 1, fatia 001 (issues/001-services-deposit-policy.md): extensão aditiva
-- de `services` com política de depósito e de comissão de no-show, ambas
-- opcionais. Ver docs/KORTEXOS_5_1_2_BLUEPRINT_ONDA_1_DRAFT.md §2.1 e §4.
--
-- Cinco colunas nullable, nenhuma constraint existente é alterada — todo
-- serviço já cadastrado nasce com NULL nas cinco (sem política), mesmo
-- comportamento de hoje. RLS é herdada de `services` (services_insert/update,
-- já owner/admin/manager) — nenhuma policy nova.

alter table public.services
  add column deposit_mechanic text check (deposit_mechanic in ('hold', 'immediate_charge')),
  add column deposit_type text check (deposit_type in ('percentage', 'fixed')),
  add column deposit_value bigint check (deposit_value >= 0),
  add column no_show_commission_type text check (no_show_commission_type in ('percentage', 'fixed')),
  add column no_show_commission_value bigint check (no_show_commission_value >= 0),
  add constraint services_deposit_pair check (
    (deposit_type is null and deposit_value is null)
    or (deposit_type is not null and deposit_value is not null)
  ),
  add constraint services_deposit_percentage_range check (
    deposit_type is distinct from 'percentage' or deposit_value <= 10000
  ),
  add constraint services_no_show_commission_pair check (
    (no_show_commission_type is null and no_show_commission_value is null)
    or (no_show_commission_type is not null and no_show_commission_value is not null)
  ),
  add constraint services_no_show_commission_percentage_range check (
    no_show_commission_type is distinct from 'percentage' or no_show_commission_value <= 10000
  );
