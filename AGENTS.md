# KortexOS — regras de arquitetura e governança

## Ordem de leitura

1. `AGENTS.md`
2. `docs/INDEX.md`
3. `docs/KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md` (visão vigente)
4. `docs/waves/KORTEXOS_5_1_2_TRUTH_MAP.md` + `docs/waves/KORTEXOS_5_1_2_MIGRATION_MAP.md` (realidade técnica atual + próximos objetos)
5. habilidade aplicável em `.agents/skills/`
6. Para qualquer mudança documental, `docs/architecture/governance/KORTEXOS_DOCUMENTATION_AUTOMATION_PROTOCOL.md`

A construção do MVP técnico (Fases 1–11, Trilhas A–E) foi encerrada formalmente em 2026-07-20 (DEC-29). `docs/legacy/mvp-tecnico/PROJECT_STATE.md` e `docs/legacy/mvp-tecnico/KORTEX_MVP_TECNICO.md` continuam corretos sobre o que está em produção hoje, mas não são mais lidos como fonte ativa de escopo — consulte-os só para contexto histórico.

## Sincronização de estado local no início da sessão

Antes de tirar qualquer conclusão sobre gates, aprovações ou estado de Onda (Blueprint aprovado, Etapa 8 autorizada, fatia implementada, PR mergeado), rode `git fetch` e compare a branch local com `origin/<branch>` (`git log <branch>..origin/<branch>`, ou ao menos observe o aviso "behind origin" do `git status`). Múltiplas sessões concorrentes no mesmo diretório de trabalho já produziram estado documental incorreto mais de uma vez — DEC-46 registra um PR que chegou a `staging` com Blueprint/ADR de uma versão intermediária por cruzamento entre sessões, e uma sessão subsequente quase repetiu uma rodada inteira de red team porque não sincronizou o local antes de avaliar se uma aprovação já existia. Local desatualizado não é evidência de que algo "ainda não aconteceu" — é só sinal de que outra sessão pode ter avançado. Se houver divergência, sincronize (`git pull --ff-only` ou no mínimo leia o log/diff remoto) antes de agir.

## Premissa

O produto é greenfield. SQL, blueprints e código externos são referências não autoritativas. Não preservar numeração, nomes, tabelas, RPCs ou limitações desses exemplos sem justificativa técnica atual.

## Fundação em produção (MVP, encerrado)

O MVP entregue e em produção — ERP vertical multi-tenant mínimo para beleza e bem-estar: organizações, usuários/memberships, clientes, profissionais, catálogo, agenda, estoque, checkout, pagamentos e caixa — é a fundação real sobre a qual a Trilha 5.1.2 constrói (ver Truth Map). Não é redesenhada do zero; é estendida.

## Invariantes

- Backend Express é dono das regras e valida o JWT do Supabase Auth.
- Tenant deriva de membership autenticada; nunca de body/query isoladamente.
- PWA não recebe `service_role` e não escreve diretamente verdade financeira.
- Toda tabela de negócio possui `organization_id`, RLS e FK tenant-safe.
- Dinheiro usa centavos inteiros; checkout é atômico e idempotente.
- Migrations são criadas pela Supabase CLI e testadas em ambiente local/descartável antes de produção.
- Exemplos antigos podem inspirar testes, nunca definir a arquitetura.
- A interface (PWA) DEVE usar exclusivamente os componentes primitivos do Kortex Design System (`<Button>`, `<Input>`, `<Badge>`, `<ActionRequestModal>`, etc.) localizados em `ui/primitives`, nunca tags HTML nativas. A tela principal (Agenda) usa obrigatoriamente layout em Timeline Vertical. Todo novo modal DEVE usar a casca compartilhada `<Modal size="sm"|"md"|"lg"|"xl">` com rolagem interna (`max-height: 90vh`) e comportamento de Bottom-Sheet em telas móveis (`< 640px`). Legendagem deve seguir o contraste mínimo WCAG AAA com fonte mínimo de `0.75rem`. Novas capacidades de Ondas DEVEM usar o hook `useFeatureFlag('flag_name')` para respeitar o Dark Launching (DEC-44/DEC-45).

## Governança documental & Docs-as-Code

- **Diátaxis obrigatório:** nenhum novo arquivo Markdown pode nascer solto na raiz de `docs/`. Classifique-o em `docs/architecture/` (visão, ADRs, decisões e governança), `docs/waves/` (Truth/Migration Map, Blueprints e evidências por onda), `docs/reference/` (dicionários, especificações e políticas) ou `docs/how-to/` (procedimentos operacionais e testes).
- **Transição não destrutiva:** `docs/INDEX.md` e o entry point do Master na raiz de `docs/` são exceções de navegação. Conteúdo histórico só é movido por tarefa explícita, com todos os links de entrada atualizados no mesmo turno.
- **Frontmatter para artefatos novos:** todo Markdown novo criado por agente em `docs/` (exceto `docs/legacy/`) ou `issues/` começa com YAML contendo `title`, `status`, `stage`, `governance_ref`, `upstream_doc` e `last_updated` (`YYYY-MM-DD`). Use `[]` ou `null` quando não houver referência real; nunca invente DEC/ADR. Arquivos de instrução (`AGENTS.md`) e `SKILL.md` seguem seus próprios frontmatters.
- **Atualização em cadeia, no mesmo turno:** ao criar/alterar Blueprint, atualize a issue rastreável; ao registrar decisão técnica, crie/atualize a ADR e a matriz DEC↔ADR; ao criar documento novo ou alterar seu estado/navegação, atualize `docs/INDEX.md`. Issue realmente concluída só vai para `issues/completed/` após atualizar todas as referências de entrada no mesmo turno.
- **Supersessão explícita:** quando uma regra for integralmente revogada, registre `STATUS: SUPERSEDED BY [DEC/ADR]` no cabeçalho do artefato anterior. Para alteração parcial, declare expressamente o escopo afetado e mantenha o restante como vigente; não falsifique uma supersessão total.
- **Validação:** antes do handoff, valide links Markdown locais afetados e preencha `DOCUMENTATION_CHECK` conforme o protocolo canônico.
- **Otimizações Obrigatórias de Código (DEC-44):** toda nova Onda do Migration Map (Onda 3 em diante) DEVE incorporar as 4 Otimizações de Pipeline: (1) Dark Launching via Feature Flags na chave `organizations.settings`; (2) Pre-flight Check SQL asserções em migrations; (3) TDD com Mocks de API + pgTAP no Express; (4) Rastreabilidade automática via Git Commit (`closes issues/NNN`).

## Processo MAS

Usar `$kortex-mvpt-orchestrator`. Delegar por domínio com ownership exclusivo de arquivos. Classificar evidência como `REAL`, `PARCIAL`, `MOCKADO`, `HARDCODED`, `CRÍTICO`, `BLOQUEADO`, `DESCONHECIDO`, `OBSOLETO` ou `CONTRADITÓRIO`.

Toda promoção entre branches/ambientes (feature → `staging`, `staging` → `main`) passa por `$kortex-environment-guardian`, que confirma a origem/destino corretos e a ausência de cruzamento entre os valores de staging e produção. Ele aciona `$kortex-delivery-guardian` como gate final antes de qualquer merge em `main` — cujo veredito passa a significar "seguro para promover a produção", não apenas "seguro para publicar".

## Gatilho Direto de Execução de Ondas (Zero Fricção)

Quando o usuário disser simplesmente **"iniciar onda N"** (ex.: "iniciar onda 3", "iniciar onda 4"):
O agente DEVE reconhecer o comando de forma implícita e executar automaticamente todo o pipeline da Onda solicitada sem exigir que o usuário cole prompts técnicos:
1. Consultar a lacuna da Onda no `docs/waves/KORTEXOS_5_1_2_MIGRATION_MAP.md` e a visão no `docs/KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md`.
2. Apresentar uma breve entrevista de alinhamento simples se houver alguma decisão de produto em aberto.
3. Criar o Blueprint em `docs/waves/onda-N/BLUEPRINT_ONDA_N.md` com YAML Frontmatter, Feature Flag (`organizations.settings`) e Pre-flight Check (DEC-44).
4. Gerar o fatiamento vertical em `issues/NNN-titulo.md` para desenvolvimento TDD com pgTAP/Jest.


## Trilha ativa: KortexOS 5.1.2

`docs/KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md` é a visão de produto final vigente **e**, desde o encerramento do MVP, a única trilha ativa de execução (Trilha F do `docs/INDEX.md`). Ela não substitui as Invariantes acima nem autoriza domínio, tabela ou endpoint novo por si só — `docs/waves/KORTEXOS_5_1_2_TRUTH_MAP.md` audita a lacuna entre a fundação em produção e aquela visão, e a promoção segue etapas gated (Migration Map → Blueprint → SQL) que exigem aprovação explícita do Platform Owner em cada uma. Estado em 2026-07-27: Onda 0 está implementada em `staging`; a correção da Onda 1 é `PARCIAL` e `NO-GO` para produção; a Onda 2 teve Etapa 8 local regularizada por DEC-42, com migrations/testes verificados, mas segue sem autorização para `staging`/`main` até os gates de ambiente, entrega e homologação; a Onda 3 (Compensation — staff levels e comissão de venda) teve o Blueprint aprovado por DEC-46, 2 rodadas de Red Team de desenho (`GO`), fatiamento liberado (`issues/017`-`020`), mas Etapa 8 (SQL) segue sem autorização própria.

## Handoff

```text
FILES_CHANGED:
- <paths e natureza>
BLOCKERS_REMAINING:
- <pendências>
VEREDITO:
- <estado e próximo passo>
DOCUMENTATION_CHECK:
- [ ] O novo documento atende ao padrão Diátaxis (ou a exceção histórica foi registrada)?
- [ ] O frontmatter YAML foi preenchido quando aplicável?
- [ ] O `docs/INDEX.md` foi atualizado quando houve novo documento, estado ou navegação?
- [ ] Alguma ADR ou DEC foi criada, afetada ou superada?
```
