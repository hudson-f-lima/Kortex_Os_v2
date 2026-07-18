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
- [legacy/](legacy/) — **Pasta obsoleta reservada para backup manual.** Contém os Master Briefings 5.1/5.1.1 e blueprints legados. *Atenção: SQL e documentos presentes nessa pasta são fontes mortas e não ditam regras sobre a arquitetura do MVP técnico.* O Master Briefing 5.1.1 (`KORTEXOS_5_1_1_MASTER_BRIEFING_CANONICO.md`) originou a Trilha E acima, mas **não é autoridade de implementação** — o próprio documento (§1.3) exige evidência separada para qualquer afirmação de estado real.
