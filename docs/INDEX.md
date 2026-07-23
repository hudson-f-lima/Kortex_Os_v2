# KORTEX OS — Single Source of Truth (SSoT) Master

Bem-vindo à documentação oficial do KortexOS. Para garantir que as regras de negócio e arquitetura não se descolem do código, seguimos o princípio de "Docs as Code" e "Single Source of Truth". Este arquivo central mapeia o estado da documentação e o Registro de Decisões.

**Encerramento formal do MVP técnico (2026-07-20, DEC-29):** a construção do MVP (Fases 1–11 + Ondas 1–7 do Design System) está concluída e em produção. A partir desta data, toda execução nova segue a Trilha F abaixo — não a numeração de "Fases 8+" usada até aqui. A documentação de planejamento/status do MVP foi arquivada em [`docs/legacy/mvp-tecnico/`](legacy/mvp-tecnico/README.md); nada foi apagado, só deixou de ser a fonte ativa.

---

## Trilha F: KortexOS 5.1.2 — Trilha Ativa (visão de produto final)

**Estado: Migration Map (etapa 6) aprovado. Blueprint (etapa 7) desbloqueado, ainda não iniciado — é o próximo passo de execução.**

- [KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md](KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md) — fonte canônica vigente da visão de produto final: tese, domínios D00–D31, motores (KortexFlow, Wallet, Negative Guard, No-show, Autonomous Operations), RAGOV, Gates 00–25, ordem de construção, cadastros canônicos e regras de configuração/comanda/gorjeta/níveis.
- [KORTEXOS_5_1_2_DECISION_LOG.md](KORTEXOS_5_1_2_DECISION_LOG.md) — histórico de decisões (DEC-01 a DEC-29, D-01 a D-09), padrão ADR, append-only. **Consulte aqui para saber o motivo/contexto de qualquer regra vigente do Master Briefing.**
- [KORTEXOS_5_1_2_GLOBAL_BENCHMARK_MAP.md](KORTEXOS_5_1_2_GLOBAL_BENCHMARK_MAP.md) — benchmark rastreável por fonte dos módulos 01–06 (Booking, Waitlist, Checkout, Ledger, Compensation, No-show), incl. Rodada 4 (multi-unidade, calendário, Action Request, Reliability Score).
- [KORTEXOS_5_1_2_COMPARATIVE_PROPOSAL.md](KORTEXOS_5_1_2_COMPARATIVE_PROPOSAL.md) — 42 achados do benchmark classificados em HERDAR/REFORÇAR/BACKLOG/DESCARTAR (DEC-22), com 4 itens REFORÇAR CRÍTICO.
- [KORTEXOS_5_1_2_TRUTH_MAP.md](KORTEXOS_5_1_2_TRUTH_MAP.md) — **v1.0, APROVADO (DEC-23).** Classifica a realidade técnica atual (REAL/PARCIAL/MOCKADO/HARDCODED/CRÍTICO/AUSENTE) contra a visão do Master Briefing, módulos 01–06. Veredito: NO-GO para promoção direta ao produto final; GO para a Etapa 6.
- [KORTEXOS_5_1_2_TRUTH_MAP_ADENDO_D02.md](KORTEXOS_5_1_2_TRUTH_MAP_ADENDO_D02.md) — **v1.0, APROVADO (DEC-25).** Cobertura complementar da Calendar Policy & Availability Layer (D02): `CRÍTICO`/`AUSENTE` confirmado em toda a extensão.
- [KORTEXOS_5_1_2_MIGRATION_MAP.md](KORTEXOS_5_1_2_MIGRATION_MAP.md) — **v1.2, APROVADO (DEC-24; revisado por DEC-27/DEC-28).** Mapeia domínio, objeto, dependência e impacto de promoção para cada lacuna `CRÍTICO`/`AUSENTE`, em 7 ondas (Onda 0: `units` · Onda 1: Payment Core · Onda 2: KortexFlow Ledger/Wallet · Onda 3: Compensation/Sale Commission · Onda 4: Calendar Policy/Availability · Onda 5: Recurring/Group/Waitlist · Onda 6: versionamento de comanda). Não define coluna, tipo, índice ou SQL — isso é do Blueprint (Etapa 7, desbloqueada, **próximo passo**).
- [KORTEXOS_5_1_2_PONTOS_CEGOS_PRE_BLUEPRINT.md](KORTEXOS_5_1_2_PONTOS_CEGOS_PRE_BLUEPRINT.md) — **v1.0, APROVADO (DEC-26; item 1 reconsiderado por DEC-27).** 5 pontos cegos pré-Blueprint (o mais profundo: a camada "Unidade", resolvida na Onda 0 do Migration Map).
- [KORTEXOS_5_1_2_INSTRUCAO_CLAUDE_CODE_TRUTH_MAP.md](KORTEXOS_5_1_2_INSTRUCAO_CLAUDE_CODE_TRUTH_MAP.md) — instrução de processo/auditoria que orientou a produção do Truth Map (Etapa 5); referência para a condução de etapas futuras equivalentes.
- [kortex-5.1.2-design/](kortex-5.1.2-design/) — assets de design de referência (mockup de dashboard, Design System docx) para o produto final; não são especificação normativa.

### Próximo passo de execução

**Blueprint (Etapa 7):** desenho técnico (domínio → objeto → coluna/tipo/índice/RLS) para as 7 ondas do Migration Map v1.2, começando pela Onda 0 (`units`) e Onda 1 (Payment Core). Exige aprovação própria do Platform Owner antes de autorizar SQL (Etapa 8).

---

## Histórico: MVP Técnico (Trilhas A–E, encerrado em 2026-07-20)

Toda a documentação de planejamento e estado operacional da construção do MVP foi arquivada em [`docs/legacy/mvp-tecnico/`](legacy/mvp-tecnico/README.md) — nada foi apagado, só deixou de ser a fonte ativa. Resumo do que cada trilha entregou:

- **Trilha A (Fundação do ERP Vertical):** arquitetura greenfield multi-tenant, RLS em 17 tabelas, checkout atômico/idempotente. Fases 1–11 concluídas e em produção.
- **Trilha B (Finanças e Engrenagens):** desconto/gorjeta reais, comissão em cascata (profissional > serviço > grupo), lançamento manual e estorno de caixa (Fase 9).
- **Trilha C (Experiência e UI):** PWA modular (8 módulos), Kortex Design System implementado globalmente (Ondas 1–7: App Shell, Timeline Vertical, Projection Cache/SWR, PWA Installer).
- **Trilha D (O Futuro Pós-MVP):** mapeamento D00–D31 e a sequência de "Fases 8+" — **substituída** pelo Migration Map da Trilha F.
- **Trilha E (Agenda e Disponibilidade):** blueprints de Availability Engine e motor transacional de agenda — **absorvidos** pelo Master Briefing 5.1.2 (D02, D07-D09) e pelo Truth Map Adendo D02.

---

## Architecture Decision Records (ADR)

Debates longos não devem se perder em chats. O *porquê* de escolhas técnicas difíceis fica imortalizado aqui — permanentes, nunca arquivados:

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

Nota: decisões de processo/governança/sequenciamento do Platform Owner (escopo de benchmark, aprovação de etapas, encerramento de trilhas) são registradas como **DEC-NN** em `KORTEXOS_5_1_2_DECISION_LOG.md`, não como ADR — os dois registros são complementares, não concorrentes (ADR = decisão técnica/arquitetural; DEC = decisão de processo/produto do Platform Owner).

---

## Governança

- [../AGENTS.md](../AGENTS.md) — Limites permanentes e formato de handoff de IA.
- [legacy/mvp-tecnico/](legacy/mvp-tecnico/README.md) — Documentação de planejamento/status do MVP técnico (Trilhas A–E), arquivada em 2026-07-20 (DEC-29). Ver manifesto para o mapa completo.
- [legacy/](legacy/) — Pasta obsoleta reservada para backup manual. Contém os Master Briefings 5.1/5.1.1 e blueprints legados. *Atenção: SQL e documentos presentes nessa pasta são fontes mortas e não ditam regras sobre a arquitetura.* O Master Briefing 5.1.1 (`KORTEXOS_5_1_1_MASTER_BRIEFING_CANONICO.md`) originou a Trilha E histórica, mas **não é autoridade de implementação** — o próprio documento (§1.3) exige evidência separada para qualquer afirmação de estado real. Também contém o asset de branding Hope OS (legado) e o bundle bruto de upload dos documentos 5.1.2 (redundante com a Trilha F, mantido só como cópia bruta).
- **Regra de dupla verdade documental (Master 5.1.2 §0.4/§0.5):** a Trilha F é a visão de produto final vigente **e**, desde o encerramento do MVP (DEC-29), também a única trilha ativa de execução. O histórico arquivado em `legacy/mvp-tecnico/` não é retrospectivamente reclassificado como errado por isso — o Truth Map já fez essa ponte antes do encerramento, e continua sendo a leitura de realidade técnica válida.
