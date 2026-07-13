---
name: kortex-supabase-guard
description: Projetar, implementar e auditar o Supabase/Postgres greenfield do KortexOS, incluindo Auth, organizations, memberships, RLS, FKs tenant-safe, grants, RPCs, concorrência, idempotência, estoque e checkout. Usar em qualquer mudança de banco do MVP técnico; tratar SQL externos apenas como exemplos e criar novas migrations pela Supabase CLI.
---

# Guardar o Supabase greenfield

## Preparar

1. Ler o estado e a especificação técnica do workspace.
2. Consultar changelog e documentação Supabase atual antes de implementar.
3. Descobrir comandos via `supabase --help` e criar arquivos com `supabase migration new`.
4. Trabalhar primeiro em Supabase local ou projeto descartável.

## Modelar

- Usar Supabase Auth para identidade.
- Modelar `organizations` e `memberships` no baseline.
- Adicionar `organization_id` a toda entidade de negócio.
- Usar FKs compostas `(organization_id, id)` para referências tenant-safe.
- Armazenar dinheiro em centavos inteiros.
- Manter movimentos de estoque e caixa rastreáveis.
- Projetar checkout como comando transacional e idempotente.

Ler [references/greenfield-schema.md](references/greenfield-schema.md) antes de alterar schema ou RPC.

## Proteger

- Habilitar RLS em toda tabela de schema exposto.
- Criar policies explícitas `TO authenticated`; combinar `USING` e `WITH CHECK` para update.
- Basear autorização em membership controlada, nunca em `user_metadata`.
- Manter helpers privilegiados em schema privado.
- Preferir `SECURITY INVOKER`; quando `SECURITY DEFINER` for necessário, fixar `search_path`, verificar `auth.uid()`/membership e revogar `PUBLIC`/`anon` imediatamente.
- Tratar grants e RLS como camadas independentes.
- Nunca expor `service_role`; no desenho API-only, conceder tabelas/RPCs de negócio somente ao backend privilegiado e exigir ator/membership dentro de comandos críticos.

## Verificar

Executar reset local, testes positivos/negativos, concorrência e advisors. Cobrir usuário sem membership, outro tenant, role insuficiente, referência cross-tenant, replay divergente, estoque insuficiente, corrida de agenda/estoque e rollback do checkout.

Não promover SQL a produção sem migration limpa, revisão e evidência reproduzível.
