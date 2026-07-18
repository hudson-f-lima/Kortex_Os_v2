# 0015 — Auditoria da arquitetura local-first / sync incremental do KortexOS

Status: auditoria concluída; item crítico (resync-on-reconnect) e Blue Team #4 (sessão expirada) corrigidos
Data: 2026-07-17
Escopo: PWA (frontend), API de sync (backend), schema Postgres/Supabase relacionado

## Atualização — item crítico corrigido

`frontend/src/shared/syncEngine.js`: a reconexão do SSE agora chama `performCatchUp()` (pull
incremental pelo cursor salvo em `meta.lastSyncId_*`) antes de reabrir o stream, em vez de
reconectar direto. Coberto por `frontend/src/shared/syncEngine.test.js` (novo — simula uma queda
de conexão e confirma que o catch-up é refeito antes do stream reabrir; confirmado que o teste
falha sem o fix). 92/92 testes de frontend passando, lint limpo.

## Atualização — Blue Team #4 corrigido (sessão expirada / 401)

`frontend/src/shared/sessionExpired.js` (novo): pub/sub simples (mesmo padrão de
`syncEngine.js`'s `LISTENERS`) para avisar "a sessão expirou" sem acoplar `apiClient.js` (módulo
puro, sem acesso ao React) ao `AuthContext`. `apiClient.js` chama `notifySessionExpired()` sempre
que uma resposta vem com `status === 401` — todo endpoint desta API exige autenticação, então 401
aqui sempre significa sessão expirada/inválida, nunca outra coisa. `AuthContext.jsx` assina isso e
força `supabase.auth.signOut()` (só se havia uma sessão ativa, evitando chamada redundante quando
várias requisições em voo recebem 401 ao mesmo tempo) — o que cascateia para a limpeza de
IndexedDB já corrigida no Blue Team #3, sem duplicar lógica de limpeza.

Testes novos: `apiClient.test.js` (401 notifica listeners, outros status não) e
`AuthContext.test.jsx` (novo arquivo — signOut é chamado com sessão ativa, não é chamado sem
sessão). Confirmado manualmente que ambos os testes falham se o comportamento correspondente for
removido. 96/96 testes de frontend passando, lint limpo, build de produção ok.

Os demais itens do Blue Team (backoff exponencial, limpeza de IndexedDB no logout, TTL de
retenção) foram corrigidos em branches paralelas não mescladas ainda a esta.

## Contexto

Auditoria dirigida (prompt cirúrgico "KORTEXOS LOCAL-FIRST PWA & INCREMENTAL SYNC") para avaliar
se a arquitetura atual de abertura instantânea + atualização silenciosa está implementada,
parcialmente implementada ou ausente, e para desenhar os próximos passos sem violar os
invariantes do projeto (backend como única fonte de verdade, cache local como projeção
descartável, frontend nunca decide regra crítica).

Toda classificação abaixo foi verificada por leitura direta de código, schema e testes —
arquivos e trechos citados. Nada foi classificado como `REAL` por inferência.

---

## VEREDITO

A arquitetura **já é**, em sua espinha dorsal, exatamente a recomendada pelo prompt: App Shell em
Cache Storage + IndexedDB como projeção limitada + pull incremental por cursor + SSE como
acelerador + backend como única autoridade para mutações críticas. **Isso não é uma proposta a
construir do zero — já está construído e em produção** (ADR 0009, `sync_events`, `/sync` e
`/sync/stream`, `useCachedQuery`, `idb.js`).

O que falta não é a espinha dorsal, e sim **robustez operacional em cima dela**: a reconexão SSE
não refaz o catch-up (pode perder deltas em silêncio), não há detecção de lacuna de sequência, o
versionamento otimista existe só para `appointments` (não é genérico), não há fila de comandos
offline (a ADR 0009 previa, mas não foi implementada), e não há tratamento de sessão expirada
(401) no `apiClient`. Nenhum desses gaps é um bloqueador para uso atual — são riscos que só se
manifestam sob rede instável ou sessão expirada, cenários ainda não cobertos por teste.

---

## CLASSIFICAÇÃO ATUAL

| Componente | Estado | Evidência | Risco |
|---|---|---|---|
| App Shell em Cache Storage (Workbox/`generateSW`) | REAL | `frontend/vite.config.js:47-60` — `navigateFallback: 'index.html'`, precache do build | Baixo |
| Cache de API (`/api/*`) | REAL | `vite.config.js:56-59` — `NetworkOnly` explícito | Baixo |
| IndexedDB — stores e operações | REAL | `frontend/src/shared/idb.js` — 7 stores + `meta`, `putRecord/getAllRecords/clearStore` | Médio (sem TTL) |
| IndexedDB — versionamento de schema local | PARCIAL | `idb.js` só tem `DB_VERSION = 1`, sem branch de migração testado | Médio |
| Escopo por tenant no IndexedDB | REAL (na leitura, não na escrita) | `useCachedQuery.js` filtra `organization_id`, fail-closed se ausente | Baixo |
| Escopo por usuário no IndexedDB | AUSENTE | Nenhum filtro por `user_id`/`created_by` encontrado | Médio (ver Red Team #7) |
| Pull incremental por cursor (`GET /sync`) | REAL | `backend/src/modules/sync/sync.route.js` + `sync.service.js`, `gt('id', sinceId)` | Baixo |
| Realtime acelerador (SSE) | REAL | `sync.route.js` — `text/event-stream`, relay de `postgres_changes` em `sync_events` | Baixo |
| Reconexão SSE com novo catch-up | **CRÍTICO** | `syncEngine.js` — reconecta direto em `runSSE()`, nunca re-chama `performCatchUp()` | **Alto** |
| Detecção de lacuna de sequência (gap) | AUSENTE | Nenhuma verificação de contiguidade de `event.id` | Alto |
| Backoff de reconexão | PARCIAL | Fixo em 5s, sem exponential backoff, sem jitter, sem teto | Médio |
| Snapshot seletivo de recuperação | AUSENTE | Nada em `syncEngine.js` chama `clearAllStores()` / resync total | Médio |
| Idempotency-Key em mutações críticas | REAL, mas por call-site | Usado manualmente em Checkout/Appointments/Estoque/Caixa/Refund | Baixo |
| Tabela `idempotency_keys` (schema + RLS) | REAL | `20260712235319_mvp_baseline.sql` + RLS habilitado em `20260717...rls_hardening...sql` | Baixo |
| `idempotency_keys` sem TTL/expiração | PARCIAL | Sem coluna `expires_at` | Baixo (crescimento sem limpeza) |
| `sync_events` (schema + RLS + trigger) | REAL | `20260716120000_sync_events.sql`, trigger em 9 tabelas | Baixo |
| Tombstone explícito de exclusão | PARCIAL | Delete é inferido por `action = 'DELETE'`, sem coluna `deleted` dedicada | Baixo (funciona, mas frágil a refactors futuros) |
| Versionamento otimista (`version` + conflito) | PARCIAL — só `appointments` | `appointments.validation.js`, `rpcError.js` mapeando `P0004` → `version_conflict` | Médio (outras entidades sem proteção) |
| Fila de comandos offline | AUSENTE | Zero ocorrências de "offline queue"/"QUEUED" no repo — ADR 0009 previa, não implementado | Baixo hoje (nada promete offline write) |
| Tratamento de sessão expirada (401) no `apiClient` | REAL (corrigido) | `apiClient.js` chama `notifySessionExpired()`; `AuthContext.jsx` assina e força signOut | Baixo |
| Testes de sync engine/IndexedDB no frontend | AUSENTE | Nenhum `syncEngine.test.js`/`idb.test.js`/`useCachedQuery.test.js` | Médio |
| Testes de `/sync` no backend | REAL, mas incompleto | `backend/tests/integration/sync.test.js` cobre cursor/insert/update/SSE handshake; não cobre gap/reconexão/delete via sync | Médio |

---

## CAUSA RAIZ DA LENTIDÃO

Não há evidência de que a lentidão percebida hoje venha de "falta de cache" — a espinha dorsal de
cache já existe. As causas prováveis (a confirmar com métricas reais, listadas na seção MÉTRICAS)
são:

1. **Nenhuma instrumentação existe hoje** (`app_shell_load_ms`, `first_usable_screen_ms`, etc. não
   são medidos em lugar nenhum do código) — logo, qualquer afirmação de "está lento" hoje é
   hipótese, não fato. Primeira ação real é medir, não otimizar às cegas.
2. O bundle principal (`index-*.js`) tem **535 KB minificados / 155 KB gzip** — acima do limite de
   aviso do Vite (`rollup-plugin` warning já observado em build local). Isso afeta o tempo até
   `first_usable_screen`, mas é ortogonal ao sync (é code-splitting de bundle, não de dados).
3. Se a percepção de lentidão for "tela em branco enquanto espera a rede", isso seria estranho
   dado que `useCachedQuery` já lê do IndexedDB antes de qualquer round-trip — mas como não há
   teste nem métrica confirmando isso em produção, fica classificado como **HIPÓTESE**, não fato.

---

## ARQUITETURA RECOMENDADA

Manter a arquitetura já construída (não substituir):

```
Backend / PostgreSQL — SSOT                                    [REAL]
        │
        ├── sync_events (trigger em 9 tabelas)                 [REAL]
        ├── GET /sync?since=cursor (pull incremental)           [REAL]
        ├── GET /sync/stream (SSE, relay de postgres_changes)   [REAL]
        └── Idempotency-Key + version (appointments)            [PARCIAL — só 1 entidade]
                │
                ▼
Sync Coordinator (syncEngine.js)
        │
        ├── Reconciliation Pull (catch-up)                      [REAL, só no startup]
        ├── Event Gap Detection                                 [AUSENTE — adicionar]
        ├── Retry / Backoff                                      [PARCIAL — trocar por exponencial]
        ├── Resync após reconexão                                [CRÍTICO — adicionar]
        └── Cache Invalidation (subscribeToStore)                [REAL]
                │
                ▼
IndexedDB — idb.js (7 stores + meta)                            [REAL]
        │
        ▼
useCachedQuery (tenant-scoped)                                  [REAL, sem user-scope]
        │
        ▼
UI reativa
```

Não recomendo reescrever nenhuma camada. Recomendo **fechar os 4 gaps críticos/altos** antes de
qualquer expansão de escopo de dados projetados.

---

## PULL VS REALTIME

- **Mecanismo canônico (reconciliação)**: pull incremental por cursor (`GET /sync?since=`) — já é
  o mecanismo correto, real, testado no backend.
- **Mecanismo acelerador**: SSE (`GET /sync/stream`) — real, mas **hoje é tratado como a única
  fonte de atualização pós-startup**, o que viola o invariante "realtime não substitui
  reconciliação". Precisa virar de fato um acelerador: se o SSE cair e reconectar, o catch-up por
  cursor deve rodar de novo antes de voltar a escutar eventos.
- **Recuperação**: não implementada. Hoje, se o IndexedDB estiver corrompido ou a versão de schema
  mudar, não há um caminho de "descartar e reconstruir" automatizado — só existe `clearAllStores`
  como função disponível, não invocada por nenhuma lógica de detecção de inconsistência.

---

## DADOS CACHEÁVEIS

| Domínio | Escopo atual | TTL | Sensibilidade |
|---|---|---|---|
| `clients` | Todos os ativos da organização (sem filtro de recência) | Nenhum | PII (nome, telefone, e-mail) |
| `professionals` | Todos os ativos da organização | Nenhum | Baixa |
| `services` / `products` / `packages` / `service_groups` | Catálogo completo ativo | Nenhum | Baixa (preço já é público na loja) |
| `appointments` | Todos sincronizados via eventos (sem janela temporal) | Nenhum | Média (agenda + `client_id`) |
| `professional_service_capabilities` / `_commissions` | Evento produzido, **não** persistido no IndexedDB (`applyEvent` ignora por não ter `storeName` mapeado) | N/A | N/A |

Nenhuma das stores tem hoje uma janela de retenção (ex.: "só agendamentos dos últimos 60 dias +
próximos 90"), ao contrário do que o prompt recomenda ("passado recente configurável + futuro
operacional configurável"). Isso não é um problema de segurança, mas é uma divergência real do
padrão de projeção limitada — hoje é efetivamente "todos os registros ativos da organização",
não uma janela.

## DADOS PROIBIDOS OU RESTRITOS

Confirmado ausente do IndexedDB (correto, nenhuma violação encontrada):
- segredos / `service_role` key — nunca entra no bundle do PWA (regra do `AGENTS.md`, confirmada
  por `vite.config.js:5-9` só expor `VITE_*`);
- ledger financeiro completo, dados de outro tenant, tokens permanentes — nenhuma evidência de
  que isso seja persistido.

Ponto de atenção real: `clients` inclui e-mail/telefone (PII) sem TTL nem limpeza no logout —
ver seção SEGURANÇA.

---

## CONTRATOS DE SYNC

Contrato real hoje (`backend/src/modules/sync/sync.route.js` + `sync.service.js`), resumido:

```
GET /sync?since={id}
→ { events: [{ id, table_name, record_id, action, payload, created_at }], ... }

GET /sync/stream  (SSE)
→ data: { id, table_name, record_id, action, payload, created_at }
```

Divergência do contrato-alvo do prompt:
- não há `next_cursor`/`has_more` explícitos no corpo — o cursor avançado no cliente é o maior
  `id` da lista recebida, implícito;
- não há `schema_version` no envelope;
- não há `entity_version` de primeira classe (só existe dentro do `payload`, e só para
  `appointments`);
- delete é `action = 'DELETE'` + `payload` = linha antes de apagar — funciona como tombstone de
  fato, mas não é um campo `deleted: true` dedicado, então qualquer novo consumidor do stream
  precisa saber ler `action` para não recriar o registro.

Nenhuma mudança de contrato é urgente — o formato atual é suficiente para o consumo atual — mas
se o escopo de sync crescer (mais tabelas, mais clientes do stream), formalizar isso evita
acoplamento implícito.

---

## POLÍTICA OFFLINE

Hoje: **toda mutação é network-only**. Não existe fila de comandos offline, mesmo para operações
de baixo risco (ex.: observação de cliente). A ADR 0009 previa uma fila para comandos permitidos,
mas isso nunca foi construído — é dívida técnica documentada, não um bug.

Isso é **seguro por padrão** (nenhuma operação crítica é confirmada offline, porque nenhuma
operação é sequer tentada offline), mas também significa que a UX "abre instantâneo, mas não deixa
fazer nada offline" ainda não existe — hoje é "abre instantâneo (leitura), mas qualquer escrita
falha sem rede".

Recomendação: não implementar fila offline agora. Não há evidência de demanda de negócio para
isso neste momento (não está nos gaps de `docs/PROJECT_STATE.md`), e a ADR 0009 já classifica isso
como algo a fazer só depois que a base (pull incremental + reconciliação) estiver robusta — que é
justamente o que esta auditoria encontrou como ainda faltando.

---

## CONFLITOS E VERSIONAMENTO

- `appointments`: mecanismo real e testado — `version` obrigatório no PATCH
  (`appointments.validation.js:44-48`), conflito mapeado do Postgres (`P0004` → `version_conflict`
  em `rpcError.js:24`), mensagem amigável no frontend
  (`AppointmentModal.jsx:12`). Isso é exatamente o padrão "server-authoritative + rejeição por
  versão" recomendado pelo prompt — mas **só existe para esta entidade**.
- Demais entidades mutáveis (`clients`, `products`, `services`, `packages`, etc.): sem
  `version`/rejeição por versão — dependem de checagens específicas por rota (ex.: 409 de SKU
  duplicado em produtos), não de um mecanismo genérico de concorrência otimista.
- Nenhum merge automático de agenda ou financeiro foi encontrado — correto, consistente com o
  invariante do prompt.

Recomendação: não generalizar version_conflict para todas as entidades agora — é esforço alto
para risco baixo nas entidades de catálogo (raramente editadas concorrentemente). Priorizar
qualquer extensão futura para entidades com alta chance de edição concorrente real (ex.: se
`clients` passar a ser editado por múltiplas recepções simultaneamente).

---

## SEGURANÇA

Verificado:
- RLS habilitada em `sync_events` (desde a criação) e em `idempotency_keys` (fix recente,
  `85fb244`), ambas com "RLS habilitado, zero políticas" documentado como intencional (tabelas de
  bookkeeping, acessadas só via `security definer`/`service_role`).
- Isolamento de tenant na leitura do IndexedDB é real (`useCachedQuery` fail-closed sem
  `organization_id`).

Gaps reais encontrados (nenhum é um incidente ativo, mas nenhum tem mitigação hoje):
1. **Sem limpeza de IndexedDB no logout** — não encontrei nenhuma chamada a `clearAllStores()` no
   fluxo de `signOut`. Se confirmado, um dispositivo compartilhado mantém a projeção do tenant/
   usuário anterior acessível após logout até a próxima sincronização sobrescrever os dados —
   requer verificação direta do fluxo de `AuthContext`/`signOut` antes de tratar como confirmado
   (não fiz essa leitura específica nesta auditoria — está listado como próxima ação).
2. **Sem TTL em `clients` (PII)** — nome/telefone/e-mail ficam no IndexedDB indefinidamente.
3. **Sem tratamento de 401** no `apiClient` — uma sessão expirada não força re-login nem limpa
   cache local automaticamente; o usuário só percebe pelo erro genérico na próxima ação.

---

## RED TEAM

| Cenário | Falha | Impacto | Causa raiz | Controle hoje | Teste | Resultado esperado |
|---|---|---|---|---|---|---|
| SSE cai e reconecta durante uma janela com mutações de outro usuário | Eventos perdidos na janela ficam permanentemente ausentes do cliente | Agenda/catálogo desatualizados silenciosamente até o próximo reload completo | `runSSE()` reconecta sem re-chamar `performCatchUp()` | Nenhum | Não existe | Reconexão deveria disparar catch-up por cursor antes de voltar a escutar SSE |
| Dois eventos de sync chegam fora de ordem (rede) | Nenhuma verificação de contiguidade de `id` | Baixo (put/delete é idempotente por id), mas gap silencioso não é detectado | Ausência de gap detection | Nenhum | Cursor deveria expor `has_more`/gap check |
| Mesmo delta aplicado duas vezes (retry de rede) | `putRecord`/`deleteRecord` por id — idempotente | Nenhum (comportamento correto) | — | Parcial (comportamento correto por acaso, não por teste) | Adicionar teste explícito de idempotência de `applyEvent` |
| Troca de usuário no mesmo dispositivo sem logout completo do cache | Dados do usuário anterior podem persistir no IndexedDB | Vazamento de dados entre sessões no mesmo tenant | Não verificado se `signOut` limpa IndexedDB | Nenhum | **Verificar antes de declarar seguro** |
| Permissão revogada enquanto app está aberto offline | Projeção local pode continuar mostrando dados/ações da permissão antiga | Ação exibida como disponível sem re-checagem — mas nenhuma mutação crítica é confirmada offline, então o pior caso é UI mostrando um botão que falhará no backend | Nenhuma invalidação reativa a mudança de permissão | Nenhum | Backend já rejeitaria a ação (fonte de verdade), então o risco real é só UX, não segurança |
| Checkout com backend indisponível | `POST /checkout` falha, erro tratado (`messageForCheckoutError`) | Nenhuma confirmação falsa — comportamento correto | Network-only para `/api/`, sem fila | Coberto indiretamente por `ComandaPage.test.jsx` | Correto: falha visível, nada fica "confirmado" localmente |
| Quota de armazenamento do IndexedDB excedida | Não testado/tratado | Desconhecido — sem `try/catch` específico para `QuotaExceededError` em `idb.js` | Ausência de tratamento | Nenhum | Deveria degradar para leitura direta da rede, não quebrar a tela |

---

## BLUE TEAM

Prioridade descendente (maior risco × menor esforço primeiro):

1. **Resync após reconexão SSE** — em `syncEngine.js`, ao reconectar (`runSSE` sendo re-chamado
   pelo `setTimeout`), rodar `performCatchUp()` de novo antes de reabrir o stream. Esforço baixo,
   fecha o gap mais crítico encontrado.
2. **Backoff exponencial com teto e jitter** no reconnect SSE, em vez do fixo 5s.
3. **Verificar e, se necessário, implementar limpeza de IndexedDB no logout** (`AuthContext`
   `signOut` → `clearAllStores()`).
4. **Tratamento de 401 no `apiClient`**: em qualquer resposta 401, forçar logout local + limpeza
   de cache, em vez de deixar cair no erro genérico.
5. **TTL/retenção configurável** para `appointments` e `clients` (janela de tempo, não "tudo").
6. **Teste de idempotência e de reconexão do syncEngine** (hoje inexistente).
7. Generalizar version_conflict para outras entidades **só se** houver evidência de edição
   concorrente real fora de `appointments`.

Não recomendado agora: fila de comandos offline, tombstone dedicado (o `action`-based já funciona),
reescrita de qualquer camada existente.

---

## TESTES

Existentes e confirmados:
- `backend/tests/integration/sync.test.js` — cursor, insert/update geram evento, SSE handshake,
  RBAC de leitura.
- `frontend/src/shared/apiClient.test.js` — header injection, mapeamento de erro, 204.
- Testes de UI que confirmam presença do header `Idempotency-Key` em mutações
  (`AppointmentModal.test.jsx`, `CaixaPage.test.jsx`, `ComandaPage.test.jsx`,
  `EstoquePage.test.jsx`).

Faltando (nenhum existe hoje):
- `syncEngine.test.js` (reconexão, catch-up, idempotência de `applyEvent`);
- `idb.test.js` (CRUD básico, `onupgradeneeded`);
- `useCachedQuery.test.js` (fail-closed sem `organizationId`, comportamento sem filtro);
- teste backend de delete via `/sync` (hoje só insert/update são exercitados);
- teste de replay de `Idempotency-Key` (reenvio do mesmo request deveria retornar o `response`
  já salvo em `idempotency_keys`, não reprocessar).

---

## MÉTRICAS

Nenhuma das métricas abaixo é hoje coletada em código (grep não encontrou nenhuma). Antes de
otimizar performance percebida, instrumentar:

```
app_shell_load_ms, first_cached_render_ms, first_usable_screen_ms,
sync_start_delay_ms, initial_sync_ms, delta_apply_ms, sync_lag_seconds,
gap_recovery_count, conflict_count, command_rejection_count,
realtime_disconnects, indexeddb_failures, stale_data_age
```

Sem essas métricas, qualquer meta de "abre em <1s" é hipótese não validada — tratar como tal.

---

## ROLLOUT

A arquitetura de base já está em produção (fases 0-3 do rollout sugerido pelo prompt já
aconteceram organicamente: app shell cacheado, IndexedDB read, pull incremental). O rollout que
falta é só para os itens do Blue Team:

```
Fase A — instrumentar métricas (sem mudança de comportamento)
Fase B — resync-on-reconnect + backoff exponencial (feature flag, fácil de reverter)
Fase C — limpeza de IndexedDB no logout + tratamento de 401
Fase D — TTL/retenção configurável por store
Fase E — testes de syncEngine/idb/useCachedQuery
```

## ROLLBACK

Cada item do Blue Team é isolado e reversível individualmente (são mudanças em `syncEngine.js`,
`apiClient.js`, `AuthContext.jsx` — nenhuma migração de schema é necessária). Não há rollback de
"arquitetura" a planejar porque não há substituição de arquitetura proposta.

## DÍVIDA TÉCNICA

- Fila de comandos offline prevista na ADR 0009 e nunca implementada — registrar explicitamente
  como dívida aceita, não pendência esquecida.
- Ausência de `entity_version`/`schema_version`/`next_cursor` explícitos no contrato de `/sync` —
  funciona hoje por convenção implícita, mas é frágil a longo prazo.
- `idempotency_keys` sem TTL — cresce sem limpeza.

## BLOQUEIOS

Nenhum bloqueio impede começar pelo item 1 do Blue Team (resync-on-reconnect) imediatamente —
é uma mudança isolada em `syncEngine.js`, sem dependência de schema ou de outro time.

## DEFINITION OF DONE

Para o Blue Team item 1 (resync-on-reconnect), considerar concluído quando:
- reconexão SSE dispara `performCatchUp()` antes de reabrir o stream;
- teste automatizado simula uma queda de conexão com eventos perdidos durante o gap e confirma
  que o catch-up os recupera;
- `npm run lint && npm test` verdes;
- nenhuma mudança de contrato de API necessária.

## PRÓXIMA AÇÃO ÚNICA

~~Implementar resync-on-reconnect em `frontend/src/shared/syncEngine.js`~~ — **feito**.
~~Blue Team #4: tratamento de sessão expirada (401)~~ — **feito** (ver atualização no topo
deste documento).

Blue Team #2 (backoff exponencial) e #3 (limpeza de IndexedDB no logout, que já estava
implementada — só faltava o teste) foram corrigidos em branches paralelas não mescladas ainda a
esta. Próximo item por prioridade depois de consolidar essas branches: TTL/retenção configurável
nas stores do IndexedDB (`appointments`/`clients`).
