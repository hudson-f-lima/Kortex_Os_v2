-- The MVP baseline locked anon/authenticated out of every public table and
-- granted service_role EXECUTE on the 4 business RPCs, but never granted the
-- backend's service_role client direct table privileges. service_role has
-- BYPASSRLS but that is moot without underlying GRANTs: reads (e.g. listing
-- a user's memberships) went through the Data API with "permission denied".
-- service_role is the trusted, server-only path (JWT + membership already
-- validated by the Express backend before it is ever used), so it is the
-- correct place for direct table access; RLS remains additional defense.

grant select, insert, update, delete on all tables in schema public to service_role;
alter default privileges in schema public grant select, insert, update, delete on tables to service_role;
