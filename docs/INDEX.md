# KORTEX OS — Single Source of Truth (SSoT) Master

Bem-vindo à documentação oficial do KortexOS. Para garantir que as regras de negócio e arquitetura não se descolem do código, seguimos o princípio de "Docs as Code" e "Single Source of Truth". Este arquivo central mapeia as Fases de Desenvolvimento e o Registro de Decisões.

## Faseamento do Projeto (Living Document)

A documentação do KortexOS é orgânica e construída em "fatias verticais".

### Trilha A: Fundação do ERP Vertical
- [KORTEX_MVP_TECNICO.md](KORTEX_MVP_TECNICO.md) — O documento que definiu a arquitetura Greenfield, o modelo Multi-Tenant e o escopo rígido do MVP.
- [PROJECT_STATE.md](PROJECT_STATE.md) — Estado operacional ao vivo deste workspace e próximo passo de engenharia.
- [REDTEAM_FASE7.md](REDTEAM_FASE7.md) — Vereditos de segurança, testes e observabilidade (CI/CD).

### Trilha B: Finanças e Engrenagens
- [PLANEJAMENTO_FINANCEIRO.md](PLANEJAMENTO_FINANCEIRO.md) — Auditoria do estado financeiro, descartando modelos obsoletos de *Partidas Dobradas* do MVP em favor do log *append-only* no banco local.
- [PLANEJAMENTO_COMISSOES.md](PLANEJAMENTO_COMISSOES.md) — O estado da arte de comissionamento de pacotes, comissões escalonadas, repasse e vínculos de serviços N:N.

### Trilha C: Experiência e UI
- [PWA_PLANEJAMENTO.md](PWA_PLANEJAMENTO.md) — Plano de Produto/UX da PWA, detalhando as rotas de *Agenda-First*, App Shell seguro e estratégia offline/cache.

### Trilha D: O Futuro (Pós-MVP)
- [PLANEJAMENTO_ROADMAP_POS_MVP.md](PLANEJAMENTO_ROADMAP_POS_MVP.md) — O mapeamento completo contra a visão estendida do Kortex (D00-D31), pesquisa global sobre *Waitlist* Automática e *Memberships* de retenção.
- [PLANEJAMENTO_EXECUCAO_UNIFICADO.md](PLANEJAMENTO_EXECUCAO_UNIFICADO.md) — O plano canônico de execução das Fases 8+, unificando e organizando as Fases das Trilhas acima.

### Trilha E: Agenda e Disponibilidade
- [PLANEJAMENTO_CALENDARIO_OPERACIONAL.md](PLANEJAMENTO_CALENDARIO_OPERACIONAL.md) — Auditoria e blueprint da Availability Engine: timezone, templates semanais, jornadas por profissional, exceções de data/feriados.
- [PLANEJAMENTO_AGENDA_TRANSACIONAL.md](PLANEJAMENTO_AGENDA_TRANSACIONAL.md) — Auditoria e blueprint do motor de mutação de agendamentos: contrato move-plan/move, matriz de conflitos, lock otimista, auditoria.

### Trilha F: KortexOS 5.1.2 — Visão de Produto Final (pós-MVP)
**Estado: Etapa 5 (Truth Map) concluída, aguardando aprovação do Platform Owner. Etapas 6+ (Migration Map, Blueprint, SQL) BLOQUEADAS até lá — ver regra de promoção sem implementação no Master, §0.4.**
- [KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md](KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md) — fonte canônica vigente da visão de produto final: tese, domínios D00–D31, motores (KortexFlow, Wallet, Negative Guard, No-show, Autonomous Operations), RAGOV, Gates 00–25, ordem de construção, cadastros canônicos e regras de configuração/comanda/gorjeta/níveis.
- [KORTEXOS_5_1_2_DECISION_LOG.md](KORTEXOS_5_1_2_DECISION_LOG.md) — histórico de decisões (DEC-01 a DEC-22, D-01 a D-09), padrão ADR, append-only.
- [KORTEXOS_5_1_2_GLOBAL_BENCHMARK_MAP.md](KORTEXOS_5_1_2_GLOBAL_BENCHMARK_MAP.md) — benchmark rastreável por fonte dos módulos 01–06 (Booking, Waitlist, Checkout, Ledger, Compensation, No-show).
- [KORTEXOS_5_1_2_COMPARATIVE_PROPOSAL.md](KORTEXOS_5_1_2_COMPARATIVE_PROPOSAL.md) — 42 achados do benchmark classificados em HERDAR/REFORÇAR/BACKLOG/DESCARTAR (DEC-22), com 4 itens REFORÇAR CRÍTICO.
- [KORTEXOS_5_1_2_TRUTH_MAP.md](KORTEXOS_5_1_2_TRUTH_MAP.md) — **v1.0, APROVADO (DEC-23).** Classifica a realidade técnica atual (REAL/PARCIAL/MOCKADO/HARDCODED/CRÍTICO/AUSENTE) contra a visão do Master Briefing, módulos 01–06. Veredito: NO-GO para promoção direta ao produto final; GO para iniciar a Etapa 6.
- [KORTEXOS_5_1_2_MIGRATION_MAP.md](KORTEXOS_5_1_2_MIGRATION_MAP.md) — **v1.2, APROVADO (DEC-24; revisado por DEC-27/DEC-28).** Mapeia domínio, nome de objeto, dependência e impacto de promoção para cada lacuna `CRÍTICO`/`AUSENTE` do Truth Map, em 7 ondas. Escopo de unidade totalmente decidido: `professional_units` (N:N), `memberships` híbrido, e classificação org-wide/catálogo-com-override/transacional para as 19 tabelas MVP existentes + todos os objetos novos. Não define coluna, tipo, índice ou SQL — isso é do Blueprint (Etapa 7, agora desbloqueada, ainda não iniciada).
- [KORTEXOS_5_1_2_TRUTH_MAP_ADENDO_D02.md](KORTEXOS_5_1_2_TRUTH_MAP_ADENDO_D02.md) — **v1.0, APROVADO (DEC-25).** Cobertura complementar da Calendar Policy & Availability Layer (D02), fora do escopo original do Truth Map v1.0 — achado do Migration Map. `CRÍTICO`/`AUSENTE` confirmado em toda a extensão (zero coluna de horário/turno/timezone no schema).
- **RODADA 4** (dentro de `KORTEXOS_5_1_2_GLOBAL_BENCHMARK_MAP.md`) — pesquisa externa cross-cutting (multi-unidade, profundidade de calendário, Action Request, Negative Guard/Reliability Score), motivada pelo mesmo padrão que gerou o adendo D02.
- [KORTEXOS_5_1_2_PONTOS_CEGOS_PRE_BLUEPRINT.md](KORTEXOS_5_1_2_PONTOS_CEGOS_PRE_BLUEPRINT.md) — **v1.0, APROVADO (DEC-26; item 1 reconsiderado por DEC-27).** 5 pontos cegos pré-Blueprint, o mais profundo sendo a camada "Unidade" (Sistema→Empresa→Unidade→Profissional, Master §1.5) sem nenhuma representação no schema. Resolução final da Unidade: `units` como entidade própria desde já (Migration Map v1.1, Onda 0), não mais adiada.
- [KORTEXOS_5_1_2_INSTRUCAO_CLAUDE_CODE_TRUTH_MAP.md](KORTEXOS_5_1_2_INSTRUCAO_CLAUDE_CODE_TRUTH_MAP.md) — instrução de processo/auditoria que orientou a produção do Truth Map (Etapa 5); referência para a condução da Etapa 6 quando aprovada.
- [kortex-5.1.2-design/](kortex-5.1.2-design/) — assets de design de referência (mockup de dashboard, design system) para o produto final; não são especificação normativa.

---

## Architecture Decision Records (ADR)

Debates longos não devem se perder em chats. O *porquê* de escolhas técnicas difíceis fica imortalizado aqui:

- [ADR 0001: Record Architecture Decisions](adr/0001-record-architecture-decisions.md)
- [ADR 0002: Checkout Atômico e Idempotente via Server-Side](adr/0002-checkout-atomico-idempotente-server-side.md)
- [ADR 0003: Comissões Escalonadas](adr/0003-comissoes-escalonadas.md)
- [ADR 0004: Política de Absorção de Descontos](adr/0004-politica-absorcao-descontos.md)
- [ADR 0005: Reversão de Comissão em Estornos](adr/0005-reversao-de-comissao-em-estornos.md)
- [ADR 0006: Gorjeta Fora da Base de Comissão e Distinção Void/Refund no Motivo do Estorno](adr/0006-gorjeta-fora-da-comissao-e-motivo-do-estorno.md)
- [ADR 0007: Sessões de Caixa e Distinção Void vs. Refund](adr/0007-cash-sessions-void-vs-refund.md)
- [ADR 0008: Capacidade Profissional — Default-Allow e Preço de Pacote](adr/0008-capacidade-profissional-default-allow-e-preco-de-pacote.md)
- [ADR 0009: Local Projection Cache e Incremental Sync](adr/0009-local-projection-cache-incremental-sync.md)
- [ADR 0010: Elegibilidade Profissional×Serviço — Modelo Tri-State e Gate Fail-Closed Configurável por Organização](adr/0010-elegibilidade-tri-state-fail-closed.md)
- [ADR 0011: Snapshot Operacional — Congelar Duração e Origem da Elegibilidade no Agendamento](adr/0011-snapshot-operacional-agendamento.md)
- [ADR 0012: Idempotência de Commands e Ativação da Concorrência Otimista em Appointments](adr/0012-idempotencia-concorrencia-otimista-appointments.md)
- [ADR 0013: Change Plan com Confirmação Explícita e Separação Booking × Settlement](adr/0013-change-plan-booking-settlement.md)
- [ADR 0014: Fase 11 — Convite de Equipe por E-mail: Provedor SMTP e Expiração](adr/0014-fase11-convite-equipe-smtp.md)
- [ADR 0015: Auditoria da Arquitetura Local-First / Sync Incremental do KortexOS](adr/0015-auditoria-arquitetura-sync-offline-first.md)

---

## Governança

- [../AGENTS.md](../AGENTS.md) — Limites permanentes e formato de handoff de IA.
- [legacy/](legacy/) — **Pasta obsoleta reservada para backup manual.** Contém os Master Briefings 5.1/5.1.1 e blueprints legados. *Atenção: SQL e documentos presentes nessa pasta são fontes mortas e não ditam regras sobre a arquitetura do MVP técnico.* O Master Briefing 5.1.1 (`KORTEXOS_5_1_1_MASTER_BRIEFING_CANONICO.md`) originou a Trilha E acima, mas **não é autoridade de implementação** — o próprio documento (§1.3) exige evidência separada para qualquer afirmação de estado real. Também contém o asset de branding Hope OS (legado por regra explícita do Master 5.1.2 §0.3) e o bundle bruto de upload dos documentos 5.1.2 (redundante com a Trilha F, mantido só como cópia bruta).
- **Regra de dupla verdade documental (Master 5.1.2 §0.4/§0.5):** a Trilha F acima é a visão de produto final vigente; as Trilhas A–E continuam descrevendo o MVP técnico materializado e **não são retrospectivamente reclassificadas como erradas** por isso — o Truth Map da Trilha F faz a ponte entre as duas, não substitui `PROJECT_STATE.md`.
