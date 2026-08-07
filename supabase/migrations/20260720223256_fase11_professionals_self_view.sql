-- Fase 11 (ADR 0014): RLS self-view em public.professionals.
-- Até aqui professionals_select usava private.is_member(organization_id), que
-- deixa QUALQUER membro ativo (inclusive papel 'professional') enxergar a
-- lista inteira de profissionais da organização — vazamento intra-org (ver
-- gate de saída da Fase 11 em PLANEJAMENTO_EXECUCAO_UNIFICADO.md §Fase 11).
-- Nova regra: owner/admin/manager/reception continuam vendo todos os
-- profissionais (precisam para agenda/comanda/caixa); um membro com papel
-- 'professional' só enxerga a própria linha (professionals.user_id = auth.uid()).
drop policy professionals_select on public.professionals;

create policy professionals_select on public.professionals for select to authenticated using (
  private.has_role(organization_id, array['owner','admin','manager','reception'])
  or (private.has_role(organization_id, array['professional']) and user_id = (select auth.uid()))
);
