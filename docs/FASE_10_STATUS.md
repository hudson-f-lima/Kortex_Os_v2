# Fase 10 — Status de Implementação

**Alvo**: Capacidades N:N profissional×serviço + Hardening do Agendamento
**Status**: ✅ CONCLUÍDO — validado localmente (pgTAP + backend + frontend + build)
**Data**: 2026-07-15/16

## Sumário de Entregas

### 1. Migrations SQL

#### 1.1 `20260715140000_fase10_capabilities.sql`
- Tabela `professional_service_capabilities`: `duration_override_minutes` (nullable, 5-1440 min), `buffer_before_min`/`buffer_after_min` (0-480 min, default 0), `price_override_cents` (nullable, ≥0), UNIQUE (organization_id, professional_id, service_id).
- RLS: select aberto a qualquer membro ativo (inclusive `professional`); insert/update `owner/admin/manager`; delete `owner/admin`.
- Índices parciais em `professional_id`/`service_id` (`where active`).
- Grants de `service_role` herdados automaticamente via `alter default privileges` da migration `20260713034222_grant_service_role_tables.sql` (confirmado via `\dp` no Postgres local — não precisou de grant explícito novo).

#### 1.2 `20260715140100_fase10_appointments_hardening.sql`
- Coluna `appointments.version` (bigint, default 1).
- Trigger `appointments_enforce_fsm`: bloqueia qualquer transição saindo de `completed` (incluindo para `completed` de novo — no-op é permitido).
- Trigger `appointments_increment_version`: incrementa `version` em todo UPDATE (fundação de lock otimista; o enforcement de `expected_version` no contrato de escrita fica para a Fase 16, que já está documentada como consumidora desta coluna).

### 2. Backend

#### 2.1 Módulo `professionalServiceCapabilities` (novo)
- `professionalServiceCapabilities.validation.js`, `.service.js`, `.route.js` — seguem exatamente o padrão de `professionalCommissions` (já testado): `assertReferencesBelongToOrg` pré-valida FK cross-org com 400 (`invalid_professional_id`/`invalid_service_id`), `mapPostgresError` mapeia duplicata (23505) para 409 `already_exists`.
- 5 rotas: `GET /professional-service-capabilities` (list + filtros), `GET /:id`, `POST` (owner/admin/manager), `PATCH /:id` (mesmo, só campos de valor — `professional_id`/`service_id` são imutáveis, mesma regra de `professional_service_commissions`), `DELETE /:id` (owner/admin).
- Registrado em `app.js`.

#### 2.2 Módulo `appointments` — hardening
- **`ends_at` agora é sempre calculado no servidor.** `ALLOWED_FIELDS` não inclui mais `ends_at`; um cliente que o envia recebe `400 unknown_fields` (falha alta, não silenciosa — decisão documentada no plano: "deve ser comunicado, não silencioso").
- `resolveDurationMinutes(organizationId, professionalId, serviceId)`: consulta `professional_service_capabilities` (active=true) por override; cai para `services.duration_minutes` se não houver capability. Mesma cascata "mais específico vence" já usada por `private.resolve_commission`.
- `create`/`update` recomputam `ends_at` sempre que `professional_id`/`service_id`/`starts_at` mudam (no update, busca a linha atual para os campos não enviados no patch).

### 3. Frontend

- `CapabilitiesTab.jsx` + `CapabilityModal.jsx` (novo), integrados em `EquipePage.jsx` como terceira seção.
- Segue o padrão real do projeto (não o que eu escrevi na primeira tentativa): `modal-overlay`/`modal-card`/`form-error`/`modal-actions` (CSS global existente, não inline styles); confirmação inline de remoção (`confirmingRemoveId`, sem `window.confirm`); erro de remoção como banner inline (sem `alert()`); o Modal chama a API diretamente e devolve o objeto salvo via `onSaved`, mesmo contrato de `ProfessionalModal`.
- `professional_id`/`service_id` ficam desabilitados no modo edição (imutáveis pós-criação, mesma regra do backend).
- `<form noValidate>`: a validação é 100% em JS (mensagens em PT-BR); sem isso, os atributos HTML5 `min`/`max` dos inputs numéricos bloqueavam o `onSubmit` antes do JS rodar — achado real durante os testes, corrigido.

### 4. Testes — todos executados e verdes localmente

| Suíte | Resultado |
|---|---|
| pgTAP (`supabase test db --local`) | **173/173 PASS** (151 base + 22 novos: `rls_professional_service_capabilities_test.sql`) |
| `supabase db advisors` | **No issues found** |
| Backend (`npm test`) | **215/215 PASS** (208 base + 7 novos de capabilities; testes de `appointments` existentes atualizados para o novo contrato server-side de `ends_at`) |
| Frontend (`npm test`) | **84/84 PASS** (75 base + 9 novos de `CapabilitiesTab`) |
| Frontend (`npm run build`) | Build de produção OK, PWA precache gerado |

## Achados reais durante a validação

1. **Bloqueio de porta Windows (Hyper-V/WSL)**: a porta padrão 54322 caía dentro de um range de exclusão dinâmica do Windows (`54230-54329`, confirmado via `netsh interface ipv4 show excludedportrange`). Contornado reiniciando o Supabase local temporariamente em portas alternativas (55321-55324) — **não commitado**, `supabase/config.toml` foi restaurado aos padrões antes do commit final, mesmo padrão já usado na sessão da Fase 9.
2. **Bug no primeiro rascunho do teste pgTAP**: `services` foi inserido sem `service_group_id` (NOT NULL) seguido de um `UPDATE` — falha imediata, já que a constraint é verificada por statement. Corrigido criando o `service_group` antes do `service`. Reescrevi o arquivo inteiro seguindo o padrão real do projeto (`pg_temp.mk_user`/`login_as`/`logout`, RPCs `create_organization`/`membership_set`) em vez de um approach ad-hoc com `do $$...$$` blocks.
3. **Falso positivo de regressão em `rpc_fase9_foundation_test.sql`**: rodar os testes de integração do backend (que persistem dados reais via HTTP contra o Supabase local) **antes** do pgTAP poluiu a tabela `orders`, expondo uma query pré-existente sem filtro de `organization_id` (`select id from orders where status='closed' order by created_at limit 1`) que pegou um pedido de outra organização. Não é um bug introduzido pela Fase 10 — é ordem de execução errada da minha parte; a CI já roda pgTAP **antes** do backend (confirmado em `.github/workflows/ci.yml`). Resolvido resetando o banco e revalidando na ordem correta.
4. **Testes de `appointments` quebrados pelo hardening de `ends_at`**: 11 envios de `ends_at` no payload em `appointments.test.js` e `appointmentsValidation.test.js` precisaram ser atualizados — os que iam pela API (não os que inserem direto via `supabaseAdmin`, que continuam enviando `ends_at` livremente por não passarem pela validação HTTP). Adicionados testes novos: recomputo de `ends_at` ao mover `starts_at`, override de capability mudando a duração resolvida, rejeição explícita de `ends_at` client-side, guard de FSM de `completed`.
5. **Mock de teste do `EquipePage` desatualizado**: a mudança de `EquipePage.jsx` para carregar `GET /services` (necessário para o novo tab) quebrou os 6 testes existentes que só mockavam `/professionals`+`/memberships` num `Promise.all`. Corrigido adicionando os mocks que faltavam.
6. **`noValidate` ausente no formulário do modal**: os atributos HTML5 `min`/`max` nos `<input type="number">` disparavam a validação nativa do navegador, que bloqueia silenciosamente o evento `onSubmit` antes do JS rodar — meu primeiro teste de validação client-side falhava mesmo com a lógica de validação correta. Descoberto isolando a causa com um teste de debug isolado; corrigido com `<form noValidate>`, consistente com o padrão de validação 100% em JS já usado no resto do projeto (`ProfessionalModal`, `ClientModal`).

## Gate de Saída — Fase 10

- [x] pgTAP validando o booking (RLS de capabilities + FSM/lock otimista de appointments): **173/173 PASS**
- [x] Teste de override de capability mudando `ends_at` resolvido (peso/duração)
- [x] Red team de override negativo/zero (CHECK constraints na migration + validação JS espelhada)
- [x] Teste de regressão confirmando que `ends_at` do cliente é ignorado (rejeitado com 400, não silenciosamente descartado)
- [x] Teste de guard de status (`completed` imutável — nenhuma transição de saída permitida, incluindo para si mesmo como no-op)
- [x] `supabase db advisors`: limpo
- [x] Backend: 215/215
- [x] Frontend: 84/84 + build de produção OK

**Verificação visual no browser não foi realizada** nesta sessão pelo mesmo motivo já documentado na Fase 9: exigiria digitar a senha de um usuário de teste via automação, o que a política de segurança do agente bloqueia por padrão. A cobertura de testes automatizados (pgTAP end-to-end contra RLS real, integração de backend contra Supabase Auth/DB local real via HTTP, componentes de frontend com Testing Library) cobre o mesmo caminho que a PWA exercitaria manualmente.

## Decisões em aberto — resolvidas nesta sessão

- **Nome final da tabela**: `professional_service_capabilities` (mantido, sem objeção).
- **`price_override` aplica em pacotes ou só avulso?**: Não resolvido nesta sessão — o `checkout_close` (Fase 5.1) ainda resolve preço de pacote via alocação proporcional do preço avulso de cada componente; capabilities de preço não foram fiadas ao checkout nesta fase (fora do escopo declarado — "PWA listando e filtrando agenda e catálogo por capacidades", não "alterar checkout"). Registrado como pendência para quando o checkout for revisitado.
- **Profissional sem vínculo pode tudo ou nada?**: Seguida a recomendação do `PLANEJAMENTO_CALENDARIO_OPERACIONAL.md §10.3` — sem capability cadastrada, cai no padrão do serviço (nem bloqueado nem customizado); não há bloqueio de agendamento por ausência de capability nesta fase (isso é escopo da Fase 15, Availability Engine).
- **Hardening (a)-(c) já estava decidido**: confirmado, não reaberto — `ends_at` server-side, guard de status, `version` — todos entregues.

## Próximas Fases

- **Fase 11** (Acesso da Equipe): SMTP de produção, convite, self-view RLS.
- **Fase 12** (Cash Sessions): Reabertura de comanda, `order_void` vs `order_refund`.
