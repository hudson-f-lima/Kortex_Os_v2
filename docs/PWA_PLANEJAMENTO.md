# Planejamento da PWA — KortexOS (Fase 6)

**Status:** planejamento. Nenhuma linha de `frontend/` foi criada ainda (`PROJECT_STATE.md`: PWA = `BLOQUEADO`).

**Ordem de leitura antes deste documento:** `AGENTS.md` → `docs/PROJECT_STATE.md` → `docs/KORTEX_MVP_TECNICO.md` → `.agents/skills/kortex-pwa-architect/SKILL.md`. Este documento não substitui nenhum desses; é a camada de decisão de produto/UX que fecha a lacuna entre a skill (regras de arquitetura da PWA) e a fase 6 do MVP técnico (§10).

## 1. Objetivo e escopo

O backend do domínio "beleza e bem-estar" está `REAL` e completo: `organizations/memberships`, `clients`, `professionals`, `services/products` (catálogo), `appointments` (agenda), `checkout` (RPC atômica e idempotente), `inventory`, `orders`, `cash_entries`. A PWA é a única peça que falta para o MVP ficar utilizável ponta a ponta.

Este documento:
1. Resume o que líderes globais de **qualquer segmento** que combina agenda + checkout + comanda + cadastro fazem bem (não só o segmento de beleza — inclui food service, retail e saúde, porque o padrão de interação é o mesmo: reservar um horário/mesa, abrir uma conta, consumir itens, fechar).
2. Traduz isso em princípios de produto compatíveis com os invariantes já fixados em `AGENTS.md` e `references/cache-policy.md`.
3. Propõe a arquitetura de módulos, os fluxos-chave e o roteiro de subfases dentro da Fase 6.

Não é um documento de arquitetura técnica de service worker (isso já existe e é normativo em `cache-policy.md`) — é o plano de produto/UX que essa arquitetura vai servir.

## 2. Pesquisa global — o que aprender com os líderes de mercado

### 2.1 Agenda-first (a tela inicial é o calendário, não um dashboard)

Fresha, Booksy, Vagaro, Zenoti e Boulevard convergem para o mesmo padrão: **a agenda é a home**, não um dashboard de métricas. Vagaro trata cada profissional como uma coluna com turno/folga/buffer configuráveis; o calendário só funciona bem quando esses parâmetros estão corretos. Booksy vence especificamente na experiência de agendamento do lado do cliente (o motivo do seu app de consumidor ser tão instalado); Fresha vence em fluidez de uso interno. O padrão comum: criar um agendamento não deve exigir sair da grade — clique/toque no slot já abre o formulário com profissional e horário pré-preenchidos.

### 2.2 Checkout e comanda (o objeto "conta aberta" é central, não um detalhe do agendamento)

Square e Toast (este último de food service, mas o padrão transfere 1:1 para comandas de salão) tratam a **conta aberta** ("open ticket"/comanda) como uma entidade de primeira classe, independente do agendamento que a originou: dá para criar uma comanda sem agendamento (walk-in), adicionar itens a qualquer momento antes de fechar, e o fechamento é uma ação distinta e final. GlossGenius e Mangomint (o mobile mais elogiado do setor) otimizam o checkout para ser feito na cadeira/estação pelo próprio profissional, não só na recepção — gorjeta e pagamento em poucos toques, sem navegar para outra tela.

### 2.3 Cadastros / CRM (perfil como registro vivo, não formulário estático)

O padrão de mercado para "customer profile" é um cartão único que junta dado operacional (histórico de agendamentos, serviços consumidos, gasto) com dado experiencial (preferências, observações, alergias) num só lugar, editável inline, sem o usuário sair do fluxo de atendimento para "ir ao cadastro". O erro comum a evitar: cadastro como formulário separado que ninguém preenche porque exige navegação extra.

### 2.4 Papéis e dispositivos (o mesmo produto, duas composições)

O mercado convergiu para um modelo híbrido: **tablet fixo na recepção** (grade completa, check-in, fila) + **celular do profissional** (a própria agenda do dia, checkout na cadeira). Zenoti, Square e Mangomint suportam ambos com o mesmo backend. Isso não é "responsivo" no sentido genérico — é composição de módulos diferente por papel: recepção vê a organização inteira, profissional vê o recorte dele.

### 2.5 PWA técnica (estado da arte 2026)

Em 2026 App Shell + Workbox é o piso, não diferencial: shell cacheado agressivamente (cache-first), API sempre network-first/network-only, imagens stale-while-revalidate. O ponto que mais gera bug em produção é a atualização do service worker — o padrão recomendado é *não* fazer `skipWaiting` silencioso; sinalizar "atualização disponível" com um indicador discreto (não um toast intrusivo) e deixar o reload sob controle do usuário — exatamente o que `cache-policy.md` já exige ("invalidar cache após deploy e oferecer reload controlado").

Para fila offline de mutações (outbox em IndexedDB + background sync), o padrão de mercado em POS é: gravar local, sincronizar depois, resolver conflito (overselling) na volta. **Este é o ponto onde o KortexOS diverge deliberadamente do "estado da arte" genérico — ver §3.4.**

### 2.6 Piso local (Trinks, Brasil)

Trinks é a referência doméstica mais próxima do segmento-alvo: agenda online, comanda eletrônica, estoque, comissão, fechamento automático de conta, app de agendamento para o cliente final + painel para o dono. É o piso funcional a igualar; o diferencial do KortexOS vem da consistência transacional (RPC atômica, idempotência, multi-tenant com RLS) que produtos desse porte no mercado local nem sempre expõem com o mesmo rigor.

## 3. Princípios de elevação ao estado da arte (decisões de produto, com o porquê)

1. **Agenda é a rota inicial pós-login**, não um dashboard. Justificativa: é a tarefa mais frequente (criar/mover/confirmar agendamento) — todo líder global testado confirma isso.
2. **Comanda é uma entidade de navegação própria**, ligada 1:1 a um `order` (já existe no schema), acessível a partir do agendamento *e* criável avulsa (walk-in/venda de produto sem agendamento). Isso já é suportado pelo backend (`checkout` não depende de `appointment_id`).
3. **Cadastro é inline, nunca bloqueante.** Criar cliente/profissional novo deve ser possível a partir do formulário de agendamento ou da comanda, sem navegação para outra tela, com o registro completo ficando disponível depois no módulo de Cadastros.
4. **Verdade única no backend — sem fila offline para dinheiro/estoque/disponibilidade.** Esta é a divergência deliberada do padrão genérico de POS (§2.5): fila offline de checkout resolve conflito *depois*, aceitando overselling temporário. `AGENTS.md` e `cache-policy.md` proíbem isso explicitamente ("nunca enfileirar checkout/estoque/caixa sem protocolo idempotente explícito", "nunca exibir disponibilidade, saldo ou fechamento antigos como atuais") porque neste domínio (agenda com exclusão de sobreposição + estoque com baixa atômica) um conflito resolvido depois já causou dano ao cliente (double-booking, venda de item sem estoque). O que a PWA **pode** e deve fazer, e que já é suportado pelo backend, é usar o `Idempotency-Key` (já obrigatório na API) para tornar checkout e ajuste de estoque **seguros contra retry em rede instável** — reenviar a mesma requisição com a mesma chave após timeout é seguro; enfileirar para reenviar depois offline não é.
5. **Multi-persona no mesmo shell.** Um único código-fonte compõe o layout por papel/dispositivo: recepção (tablet, grade completa, fila do dia) e profissional (mobile, agenda pessoal + checkout na estação). Papéis já existem no backend (`owner/admin/manager/reception`) — a PWA não inventa um novo modelo, só decide *quais módulos* cada papel vê por padrão.
6. **Atualização controlada, nunca silenciosa.** Indicador discreto de "nova versão disponível" + ação explícita de recarregar, nunca troca de bundle no meio de uma comanda aberta.
7. **Rascunho local só para o que não é verdade crítica.** Ex.: texto de observação de cliente sendo digitado, filtro de agenda selecionado, item ainda não confirmado numa comanda em edição — nunca o resultado de um checkout ou ajuste de estoque.

## 4. Arquitetura proposta

### 4.1 Mapa de módulos (frontend ⇄ backend)

| Módulo PWA | Rotas backend consumidas | Persona primária | Observação |
|---|---|---|---|
| **Agenda** (home) | `/appointments`, `/professionals`, `/services` | recepção, profissional | grade dia/semana por profissional; criar/mover/cancelar |
| **Comanda / Checkout** | `/checkout`, `/orders`, `/catalog` | recepção, profissional | comanda aberta → itens → fechamento; walk-in sem agendamento |
| **Cadastros — Clientes** | `/clients` | recepção | perfil único: dados + histórico de agendamentos/consumo |
| **Cadastros — Equipe** | `/professionals`, `/memberships` | owner/admin | perfil + papel + disponibilidade |
| **Catálogo** | `/catalog`, `/services`, `/products` | manager | serviços e produtos, preço (exibido, nunca calculado no cliente) |
| **Estoque** | `/inventory/adjustments`, `/inventory/movements` | manager | ajuste via RPC idempotente; leitura de movimentos |
| **Caixa** | `/cash-entries` | owner/admin/manager | somente leitura (nenhuma RPC de lançamento manual existe ainda no backend — não inventar escrita na PWA) |
| **Organização/Onboarding** | `/organizations`, `/memberships` | owner | criação de org, convite/edição de papel |

Nenhum módulo novo é inventado além do que o backend já expõe — a PWA reflete os domínios de `KORTEX_MVP_TECNICO.md §4`, não os antecipa.

### 4.2 App shell e navegação

- Shell mínimo: header (organização + usuário), navegação primária (bottom nav em mobile, rail lateral em desktop/tablet), área de conteúdo por módulo carregado sob demanda (code-splitting por módulo, conforme a skill).
- Composição por papel: `reception`/`owner`/`admin` veem Agenda + Comanda + Cadastros + Catálogo + Estoque + Caixa; `manager` idem sem Organização; papel sem `reception` (se existir um perfil "profissional puro") vê Agenda (recorte próprio) + Comanda.
- Deep link direto para uma comanda ou agendamento específico (ex.: notificação → abre direto no registro).

### 4.3 Camada de dados

- Cliente HTTP único, injeta `Authorization: Bearer` e `X-Organization-Id`; trata os erros padronizados (`{code, message, request_id}`) com mapeamento para os estados de UI do §4.4.
- Cache de servidor em memória (ex.: camada de query cache) com TTL curto só para reduzir requisições redundantes de tela — nunca como fonte de verdade entre navegações críticas (reabrir a tela de checkout sempre revalida).
- Nenhum dado financeiro, de estoque ou disponibilidade é persistido em IndexedDB/localStorage como se fosse atual — reforça o invariante de `AGENTS.md`.
- `Idempotency-Key` gerada no cliente (UUID) no início de uma tentativa de checkout/ajuste de estoque e reaproveitada em retries da mesma tentativa (não em tentativas novas do usuário).

### 4.4 Estados explícitos por módulo

Todo módulo que faz mutação (Comanda, Agenda, Cadastros, Estoque) implementa os 7 estados exigidos pela skill: `loading`, `vazio`, `erro recuperável`, `offline`, `conflito` (ex.: 409 profissional com agenda dupla, comanda já fechada), `sem permissão` (403 por papel) e `atualização disponível`. Nenhum desses deve ser um "crash" genérico — o contrato de erro já vem estruturado do backend.

### 4.5 Política de cache

Reaproveitar sem alteração a tabela normativa de `references/cache-policy.md` (app shell network-first, JS/CSS com hash cache-first, API autenticada network-only, mutações network-only sem fila). Este documento não redefine essa política — só a aplica módulo a módulo no §4.1.

## 5. Fluxos-chave (nível de wireframe textual)

**5.1 Home = Agenda.** Grade do dia por profissional. Tocar em slot vazio → modal de novo agendamento (cliente, serviço, profissional, horário pré-preenchidos pelo slot); campo de cliente permite buscar ou criar inline. Tocar em agendamento existente → detalhe com ação primária "Abrir comanda".

**5.2 Abrir comanda → checkout.** A partir do agendamento (itens do serviço pré-carregados) ou avulsa (walk-in, busca de cliente/produto). Adicionar itens do catálogo; total e descontos são sempre recalculados pelo backend antes de exibir (nunca somados no cliente). Fechar comanda = uma ação única com `Idempotency-Key`; tela de confirmação de pagamento (split, gorjeta) é o único momento antes do fechamento; depois de fechada, é somente leitura.

**5.3 Cadastro rápido.** Criar cliente ou profissional novo sem sair do fluxo de agendamento/comanda (campo "novo cliente" abre um formulário mínimo inline: nome + telefone; completar o resto depois no módulo de Cadastros).

**5.4 Caixa.** Lista somente leitura de `cash_entries` com filtro por período/tipo — sem lançamento manual (não existe RPC para isso ainda; não inventar escrita client-side que o backend não sustenta).

## 6. Roteiro de subfases (dentro da Fase 6 de `KORTEX_MVP_TECNICO.md`)

| Subfase | Entrega | Depende de |
|---|---|---|
| 6.1 | ✅ App shell, autenticação (Supabase Auth só para login/sessão), navegação por papel, manifest + ícones instaláveis | — |
| 6.2 | ✅ Módulo Agenda (grade, criar/mover/cancelar, filtro por profissional) | 6.1 |
| 6.3 | ✅ Módulo Comanda/Checkout (abrir, adicionar item, fechar com idempotência, split de pagamento — gorjeta fora do escopo, sem suporte no schema) | 6.2 |
| 6.4 | ✅ Cadastros (clientes, equipe) + Catálogo (grupos, serviços, produtos, pacotes) + Estoque (ajuste, movimentações) | 6.1 |
| 6.5 | Caixa (leitura) + Organização/onboarding (criar org, convidar membro) | 6.1 |
| 6.6 | Hardening PWA: service worker por classe de cache, fluxo de atualização controlada, estados de offline/conflito em todos os módulos, orçamento de performance (§7) | 6.2–6.5 |

## 7. Orçamento técnico e métricas de sucesso

Conforme a skill: medir bundle inicial, LCP, INP, payload de API por tela e taxa de acerto de cache estático. Metas de partida sugeridas para o MVP (a validar com dado real de uso, não como trava rígida): bundle inicial do shell abaixo de 150KB comprimido; LCP da Agenda abaixo de 2,5s em rede 4G; nenhuma tela de mutação crítica sem os 7 estados do §4.4.

## 8. Riscos e decisões em aberto

- **Não existe RPC de lançamento manual de caixa** (`income`/`expense`/`refund` avulsos) — se o produto precisar disso, é decisão de schema/backend fora do escopo desta PWA, não algo a contornar no frontend.
- **Definição de "profissional puro" como papel de app** (login individual do profissional vs. acesso só via `reception`/`manager` na conta da organização) não está fechada no MVP técnico — impacta o §4.2 (composição por papel) e deveria ser decidida antes de 6.2.
- **Reconciliação de conflito de agenda (409 `professional_double_booked`)** precisa de UX explícita (sugerir próximo horário livre), não só mensagem de erro.
- **Gorjeta não existe no schema de checkout** — `checkout_close` exige que a soma de `payments` feche exatamente com o subtotal calculado dos itens (sem campo extra), então a Comanda (6.3) não a implementou. Se o produto precisar, é decisão de schema/RPC fora do escopo desta PWA (provavelmente um campo novo em `payments` ou `orders`, com as implicações de comissão que isso traria).
- **Não existe vínculo persistido entre agendamento e pedido** (`appointments.id` não aparece em `orders`) — "abrir comanda a partir do agendamento" (6.3) é só pré-preenchimento de UI; a marcação do agendamento como `completed` após o fechamento é uma segunda chamada independente e best-effort, não uma transação única.
- **`professional` não tem nenhuma permissão de escrita em `checkout` nem leitura em `orders`** no backend atual — a Comanda (6.3) mostra esse papel como indisponível para operar comandas, mesmo o módulo estando na lista de navegação dele. Se o produto quiser mesmo "checkout na cadeira pelo profissional" (§2.2), isso exige abrir esses allowlists no backend primeiro.
- **Não existe convite de membro por e-mail** (Fase 6.4) — `membership_set` (`PUT /memberships/:userId`) exige um `user_id` que já seja uma sessão real do Supabase Auth; o backend não expõe busca de usuário por e-mail nem um fluxo de convite. A Equipe (6.4) só permite alterar papel/atividade de uma membership que já existe (listada por `user_id` truncado, sem e-mail/nome — o backend nunca expôs isso). "Convidar membro" (§6, Subfase 6.5) continua em aberto até existir uma decisão de produto/backend para esse fluxo — não inventado no frontend.
- **Cliente não tem campo de preferências/observações/alergias** no schema (`clients` só tem `name`/`phone`/`email`/`active`) — o "perfil como registro vivo" do §2.3 foi implementado como cadastro + histórico de agendamentos (via `GET /appointments?client_id=`), sem o dado experiencial que o schema não sustenta.
- **Comissão por profissional×serviço (`professional_service_commissions`, Fase 5.1) não tem UI própria** — a Fase 6.4 cobre a cascata até o nível 2 (grupo → serviço, editável em Catálogo); o override de nível 1 (profissional específico) só existe hoje via API direta, não foi adicionado a Equipe nem a Catálogo por não estar no mapa de módulos do §4.1 e para não inflar o escopo desta subfase.

## Fontes

- [Fresha — Best Salon Software 2026](https://www.fresha.com/for-business/salon/best-salon-software)
- [Zenoti — Best Salon Booking Software 2026](https://www.zenoti.com/thecheckin/best-salon-booking-software)
- [Square — Open Tickets best practices](https://squareup.com/help/us/en/article/6108-open-tickets-best-practices)
- [Square Appointments — Features](https://squareup.com/us/en/appointments/features)
- [Toast — Manage Orders / Open View](https://support.toasttab.com/en/article/New-POS-Experience-Ordering-Screens)
- [Toast — Get Started With Open View](https://support.toasttab.com/en/article/Get-Started-Open-View)
- [GlossGenius](https://glossgenius.com/) e [GlossGenius vs. Boulevard](https://www.goodcall.com/appointment-scheduling-software/boulevard-vs-glossgenius)
- [Zenoti — POS system for salon and spa](https://www.zenoti.com/thecheckin/pos-system-for-salon-and-spa)
- [SalonBiz — Modern salon reception desk](https://salonbizsoftware.com/blog/modern-salon-reception-desk/)
- [Trinks — sistema de gestão para salões](https://www.trinks.com/)
- [Trinks — Blog, comanda eletrônica e estoque](https://blog.trinks.com/novidades-para-seu-salao-de-beleza-comanda-eletronica-e-estoque-cada-vez-mais-rapidos)
- [Digital Applied — Progressive Web Apps 2026 Guide](https://www.digitalapplied.com/blog/progressive-web-apps-2026-complete-development-guide)
- [MagicBell — Offline-First PWAs: Service Worker Caching Strategies](https://www.magicbell.com/blog/offline-first-pwas-service-worker-caching-strategies)
- [dev.to — On PWA Update Patterns](https://dev.to/thepassle/on-pwa-update-patterns-4fgm)
- [dev.to — Hidden Problems of Offline-First Sync: Idempotency, Retry Storms, Dead Letters](https://dev.to/salazarismo/the-hidden-problems-of-offline-first-sync-idempotency-retry-storms-and-dead-letters-1no8)
- [Medium/Adam Fard — CRM Design Best Practices](https://medium.com/@adam.fard/crm-design-best-practices-966bbb1d60c5)
