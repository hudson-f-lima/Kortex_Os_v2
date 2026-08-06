-- Onda 5, fatia 036 (issues/036-onda5-service-role-dml-revoke.md).
-- O service_role pode executar as RPCs aprovadas, mas nunca escrever as
-- tabelas de domínio diretamente.

begin;
select plan(7);

select ok(
  not has_table_privilege('service_role', 'public.appointment_series', 'INSERT, UPDATE, DELETE, TRUNCATE'),
  'service_role has no direct DML on appointment_series'
);
select ok(
  not has_table_privilege('service_role', 'public.appointment_series_conflicts', 'INSERT, UPDATE, DELETE, TRUNCATE'),
  'service_role has no direct DML on appointment_series_conflicts'
);
select ok(
  not has_table_privilege('service_role', 'public.appointment_groups', 'INSERT, UPDATE, DELETE, TRUNCATE'),
  'service_role has no direct DML on appointment_groups'
);
select ok(
  not has_table_privilege('service_role', 'public.appointment_participants', 'INSERT, UPDATE, DELETE, TRUNCATE'),
  'service_role has no direct DML on appointment_participants'
);
select ok(
  not has_table_privilege('service_role', 'public.waitlist_entries', 'INSERT, UPDATE, DELETE, TRUNCATE'),
  'service_role has no direct DML on waitlist_entries'
);
select ok(
  not has_table_privilege('service_role', 'public.waitlist_entry_professionals', 'INSERT, UPDATE, DELETE, TRUNCATE'),
  'service_role has no direct DML on waitlist_entry_professionals'
);
select ok(
  not has_table_privilege('service_role', 'public.waitlist_offers', 'INSERT, UPDATE, DELETE, TRUNCATE'),
  'service_role has no direct DML on waitlist_offers'
);

select * from finish();
rollback;
