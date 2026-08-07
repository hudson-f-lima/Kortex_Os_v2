-- Onda 5, fatia 036 (issues/036-onda5-service-role-dml-revoke.md, DEC-54).
-- Forward-only: a escrita de domínio passa exclusivamente pelas RPCs
-- security-definer; service_role não pode contornar os invariantes com DML.

do $$
begin
  if to_regclass('public.appointment_series') is null
    or to_regclass('public.appointment_series_conflicts') is null
    or to_regclass('public.appointment_groups') is null
    or to_regclass('public.appointment_participants') is null
    or to_regclass('public.waitlist_entries') is null
    or to_regclass('public.waitlist_entry_professionals') is null
    or to_regclass('public.waitlist_offers') is null then
    raise exception 'pre-flight failed: Onda 5 domain tables must exist before fatia 036';
  end if;
end $$;

revoke insert, update, delete, truncate on table
  public.appointment_series,
  public.appointment_series_conflicts,
  public.appointment_groups,
  public.appointment_participants,
  public.waitlist_entries,
  public.waitlist_entry_professionals,
  public.waitlist_offers
from service_role;
