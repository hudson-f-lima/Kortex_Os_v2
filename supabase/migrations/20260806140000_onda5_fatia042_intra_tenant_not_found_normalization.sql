-- Implementa docs/waves/onda-5-recurring-group-waitlist/KORTEXOS_5_1_2_BLUEPRINT_ONDA_5.md
-- Onda 5, fatia 042 (issues/042-onda5-intra-tenant-existence-oracle-hardening.md,
-- DEC-57). Hardening pós Red Team final: nas 10 operações do dispatcher que
-- resolvem unit_id por lookup de um objeto existente (série, conflito de
-- série, grupo, oferta), reception de outra unidade recebia 42501
-- 'insufficient unit permission' — distinguível do P0002 'not found' que a
-- mesma RPC lança para um ID inexistente. Isso deixa uma reception já
-- autenticada no tenant inferir que o objeto existe em alguma unidade que
-- ela não acessa. Normaliza para o mesmo P0002/mensagem que um ID
-- inexistente já produzia. As 4 operações de create (unit_id vem do próprio
-- payload do actor, não há objeto oculto) continuam com 42501 — não há
-- oráculo ali, e trocar degradaria a clareza do erro sem ganho de segurança.
-- Nenhum DML direto é reaberto; owner/admin/manager e reception da unidade
-- correta seguem liberados exatamente como antes.

set check_function_bodies = off;

-- Fonte única da checagem "este actor pode escrever nesta unidade" —
-- extraída para ser reusada tanto pelo caminho 42501 (create) quanto pelo
-- caminho P0002 (lookup), sem duplicar a consulta de membership.
CREATE OR REPLACE FUNCTION private.onda5_actor_can_write_unit(p_organization_id uuid, p_actor_user_id uuid, p_unit_id uuid)
 RETURNS boolean
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.memberships m
    JOIN public.organizations o ON o.id = m.organization_id AND o.active
    WHERE m.organization_id = p_organization_id
      AND m.user_id = p_actor_user_id
      AND m.active
      AND (
        m.role IN ('owner', 'admin', 'manager')
        OR (m.role = 'reception' AND m.unit_id = p_unit_id)
      )
  );
$function$
;

-- Mesmo contrato de antes (42501, usada pelas 4 operações de create via
-- assert_actor_can_write_onda5_target, e diretamente por waitlist_entry_create)
-- — só passa a delegar a checagem para o helper compartilhado.
CREATE OR REPLACE FUNCTION private.assert_actor_can_write_fact_unit(p_organization_id uuid, p_actor_user_id uuid, p_unit_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
begin
  if not private.onda5_actor_can_write_unit(p_organization_id, p_actor_user_id, p_unit_id) then
    raise exception 'insufficient unit permission' using errcode = '42501';
  end if;
end;
$function$
;

-- Mensagem not-found que cada operação de LOOKUP já lança hoje para um ID
-- inexistente (texto lido diretamente dos `_unsafe` correspondentes, fatia
-- 037) — NULL para as 4 operações de create, sinalizando "sem oráculo aqui,
-- mantenha 42501".
CREATE OR REPLACE FUNCTION private.onda5_write_target_not_found_message(p_operation text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT CASE p_operation
    WHEN 'appointment_series_extend_window' THEN 'series not found'
    WHEN 'appointment_series_update' THEN 'series not found'
    WHEN 'appointment_series_cancel' THEN 'series not found'
    WHEN 'appointment_series_conflict_retry' THEN 'series conflict not found'
    WHEN 'appointment_group_member_add' THEN 'group not found'
    WHEN 'appointment_group_update' THEN 'group not found'
    WHEN 'appointment_group_cancel' THEN 'group not found'
    WHEN 'waitlist_offer_accept' THEN 'waitlist offer not found'
    WHEN 'waitlist_offer_decline' THEN 'waitlist offer not found'
    WHEN 'waitlist_offer_expire' THEN 'waitlist offer not found'
    ELSE NULL
  END;
$function$
;

CREATE OR REPLACE FUNCTION private.assert_actor_can_write_onda5_target(p_organization_id uuid, p_actor_user_id uuid, p_operation text, p_payload jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
declare
  v_unit_id uuid := private.onda5_write_target_unit(p_organization_id, p_operation, p_payload);
  v_not_found_message text := private.onda5_write_target_not_found_message(p_operation);
begin
  if v_unit_id is null then
    -- Mantém o contrato anterior para ID inexistente ou de outro tenant: o
    -- corpo original decide o erro `not found`, sem revelar unidade alguma.
    return;
  end if;

  if v_not_found_message is null then
    -- Create: unit_id vem do próprio payload do actor, não há objeto oculto
    -- para proteger — 42501 continua o erro correto e mais claro.
    perform private.assert_actor_can_write_fact_unit(p_organization_id, p_actor_user_id, v_unit_id);
    return;
  end if;

  -- Lookup: normaliza para o mesmo not-found que um ID inexistente já
  -- produz (issue 042/DEC-57) — reception de outra unidade não distingue
  -- "existe alhures" de "nunca existiu". owner/admin/manager continuam
  -- liberados org-wide, reception da unidade certa também.
  if not private.onda5_actor_can_write_unit(p_organization_id, p_actor_user_id, v_unit_id) then
    raise exception '%', v_not_found_message using errcode = 'P0002';
  end if;
end;
$function$
;
