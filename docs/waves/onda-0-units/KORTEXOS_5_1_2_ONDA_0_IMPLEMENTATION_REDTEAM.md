# Onda 0 — Red Team da Implementação

**Data:** 2026-07-24
**Escopo:** repositório e ambiente Supabase locais
**Branch:** `codex/fix-onda0-local-gates`
**Promoção remota:** não executada

## Resultado executivo

A primeira declaração de conclusão da Onda 0 era **CONTRADITÓRIA** com o código. Quatro rodadas adversariais reprovaram a implementação antes do fechamento: a primeira encontrou isolamento unitário incompleto; a segunda encontrou bypass pelo RPC legado, perda do ator humano, auditoria de no-op, timezone configurável e falta de trigger para a unidade default; a terceira encontrou permissões profissionais órfãs após perda do perfil/vínculo; a quarta encontrou a atribuição do ator humano ausente na inativação/unlink via `PATCH`.

Os achados foram corrigidos em migration forward-only, backend, testes e documentação. A evidência final abaixo é local e reproduzível. Ela não autoriza commit, push, merge ou deploy.

## Rodada 1 — NO-GO

Achados classificados:

- **REAL/ALTO:** fatos e sync ainda operavam com leitura org-wide em caminhos sensíveis;
- **REAL/ALTO:** profissionais criados após o backfill não recebiam vínculo automático;
- **REAL/ALTO:** `/professionals` expunha perfis e `user_id` para papel profissional;
- **REAL/MÉDIO:** exclusão em cascade não possuía trilha suficiente;
- **CONTRADITÓRIO:** documentação afirmava conclusão enquanto o pgTAP focalizado falhava.

Correções:

- RLS e backend unit-aware para agenda, pedidos, checkout, clientes e sync REST/SSE;
- vínculo automático/auditado de novos profissionais;
- DTO self-only para profissional;
- lifecycle tenant-safe de `professional_units`;
- expansão dos testes adversariais.

## Rodada 2 — NO-GO

Achados classificados:

- **REAL/ALTO:** `/memberships` e `/convites` ainda chamavam `membership_set`, permitindo contornar auditoria/revogação;
- **REAL/ALTO:** delete humano de profissional chegava ao cascade como `system`;
- **REAL/MÉDIO:** `professional_unit_assign` e `membership_scope_set` auditavam repetições sem mudança;
- **CONTRADITÓRIO/MÉDIO:** `unit_create` aceitava timezone embora a Onda 0 fixe `America/Sao_Paulo`;
- **PARCIAL/MÉDIO:** exatamente uma default era preservada pelos comandos, mas não por trigger contra escrita direta privilegiada;
- **REAL/BAIXO:** relatório referenciado inexistente e contagens documentais desatualizadas.

Correções:

- APIs migradas para `membership_scope_set`; `membership_set` legado sem `EXECUTE` para `service_role`;
- revogação atômica de permissões ao sair do papel/escopo profissional, sem ressurreição;
- membership profissional pendente permitido apenas para fechar o ciclo FK do convite; permissões permanecem fail-closed até existir perfil e vínculo ativo;
- `professional_delete` propaga o ator humano ao cascade auditado;
- comandos idempotentes não criam eventos de auditoria em no-op;
- `unit_create` sem parâmetro de timezone e valor fixo `America/Sao_Paulo`;
- trigger adicional impede remover/desativar diretamente a única default ativa;
- documentação e matriz de evidências atualizadas.

## Rodada 3 — NO-GO

Achado classificado:

- **REAL/CRÍTICO:** após delete, inativação ou unlink do perfil, a membership e permissões profissionais podiam permanecer ativas; o middleware carregava `view_all` mesmo sem perfil/vínculo e ampliava clientes, agenda e sync.

Correções:

- trigger de lifecycle desativa a membership profissional e revoga permissões no delete, `active=false` ou mudança/remoção de `user_id`;
- delete via RPC preserva o ator humano; mutações internas sem ator são registradas como `system`;
- middleware somente carrega permissões após comprovar perfil ativo e `professional_units` ativo na unidade da membership;
- testes reproduzem o bypass contra clientes, agenda e sync, além dos três eventos de lifecycle.

## Rodada 4 — NO-GO

Achado classificado:

- **REAL/MÉDIO:** o fail-closed de lifecycle já estava correto, mas `PATCH /professionals/:id` atualizava diretamente a tabela; inativação ou unlink chegavam à auditoria como `system`, embora a requisição tivesse um ator humano autenticado.

Correções:

- novo comando `professional_update`, transacional, tenant-safe e restrito a `service_role`, valida o patch e propaga `p_actor_user_id` ao trigger de lifecycle;
- a rota Express passa `req.auth.userId` e deixou de atualizar diretamente `professionals`;
- pgTAP cobre inativação e unlink pelo comando; a integração HTTP confirma `actor_kind = 'user'`, `actor_user_id` do owner, revogação imediata e bloqueio da requisição seguinte.

## Matriz final de gates

| Gate | Estado | Evidência local |
|---|---|---|
| Cânone/escopo | PASS | timezone fixo; nenhuma UI ou domínio fora da Onda 0 |
| Tenant | PASS | organização e unidade validadas conjuntamente; ataques cross-tenant/cross-unit negados |
| Privilégios | PASS | comandos novos com `SECURITY DEFINER`, `search_path` fixo e `EXECUTE` somente de `service_role` |
| Membership/permissões | PASS | comando canônico, legado desabilitado, revogação/auditoria e perfil pendente fail-closed |
| Agenda | PASS | vínculo ativo, leitura própria/permissão explícita e mutações cross-unit negadas |
| Dinheiro/estoque | PASS | checkout default-only, idempotência, centavos, locks e consistência pai-filho preservados |
| Sync REST/SSE | PASS | filtro por request/listener, papel, unidade e perfil |
| Topologia | PASS | locks por organização, exatamente uma default, timezone fixo e comandos idempotentes |
| Auditoria | PASS | append-only, ator humano no delete/PATCH e ausência de evento em no-op |
| Supabase | PASS | reset limpo, 15 migrations, 346/346 pgTAP e advisors sem achados |
| Backend | PASS | 255/255; lint com 0 erros e 1 warning preexistente |
| PWA | PASS | 106/106; build de produção aprovado; nenhum arquivo frontend alterado após o gate |
| Segredos/supply chain | PASS | nenhum segredo ou manifesto/lockfile introduzido no diff |
| Histórico Git | BLOQUEADO | remoto não inspecionado nesta etapa local |
| Promoção/deploy | BLOQUEADO | exige environment/delivery guardian e autorização explícita |

## Evidência executável

```text
supabase db reset --local
  PASS — 15 migrations aplicadas do zero

supabase test db --local supabase/tests/rls_units_test.sql
  PASS — 99/99

supabase test db --local
  PASS — 346/346 em 16 arquivos

supabase db advisors --local --type all --level warn --fail-on error
  PASS — No issues found

backend: npm.cmd run test
  PASS — 255/255

backend: npm.cmd run lint
  PASS — 0 erros; 1 warning preexistente em fase9.test.js

frontend: npm.cmd run test / npm.cmd run build
  PASS — 106/106 e build aprovado

git diff --check
  PASS — apenas avisos de normalização LF/CRLF
```

Uma execução paralela de pgTAP e backend foi descartada como evidência porque ambas as suítes compartilham o mesmo banco e interferiram nas contagens. O resultado canônico acima foi obtido sequencialmente após novo `db reset`.

## Veredito

- **GO local para considerar a Onda 0 concluída no repositório local.**
- **BLOQUEADO para promoção remota/produção.**
- Próximo passo autorizado pelo estado documental: Blueprint da Onda 1; promoção da Onda 0 segue fluxo próprio e gateado.
