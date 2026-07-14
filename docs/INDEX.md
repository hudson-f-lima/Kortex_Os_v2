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

---

## Architecture Decision Records (ADR)

Debates longos não devem se perder em chats. O *porquê* de escolhas técnicas difíceis fica imortalizado aqui:

- [ADR 0001: Record Architecture Decisions](adr/0001-record-architecture-decisions.md)
- [ADR 0002: Checkout Atômico e Idempotente via Server-Side](adr/0002-checkout-atomico-idempotente-server-side.md)
- [ADR 0003: Comissões Escalonadas](adr/0003-comissoes-escalonadas.md)
- [ADR 0004: Política de Absorção de Descontos](adr/0004-politica-absorcao-descontos.md)

---

## Governança

- [../AGENTS.md](../AGENTS.md) — Limites permanentes e formato de handoff de IA.
- [legacy/](legacy/) — **Pasta obsoleta reservada para backup manual.** Contém o Master Briefing 5.1 e blueprints legados. *Atenção: SQL e documentos presentes nessa pasta são fontes mortas e não ditam regras sobre a arquitetura do MVP técnico.*
