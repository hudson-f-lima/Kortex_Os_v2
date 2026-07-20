# KORTEXOS™ — Truth Map 5.1.2 — Adendo D02 (Calendar Policy & Availability Layer)

**Versão:** v1.0
**Data:** 2026-07-20
**Produzido por:** Claude Code, seguindo `$kortex-truth-mapper`, em resposta à recomendação registrada no Migration Map (DEC-24, §1 "Achado de cobertura descoberto durante o mapeamento").
**Escopo:** exclusivamente a **Calendar Policy & Availability Layer** (Master Parte III §2 — subconjunto do domínio D02 Business Configuration & Policy Layer). Não audita o restante de D02 (cadastros de forma de pagamento, cliente, staff, serviço etc. — Parte II), que já teve evidência parcial coberta indiretamente pelos módulos 01–06 do Truth Map v1.0.
**Autoridade deste artefato:** classifica realidade técnica (mesma taxonomia do Truth Map v1.0: REAL/PARCIAL/MOCKADO/HARDCODED/CRÍTICO/AUSENTE). Não implementa, não altera o veredito já registrado em DEC-23, não é uma nova etapa da ordem de construção — é cobertura complementar à etapa 5, referenciada pela etapa 6.
**Status:** **APROVADO pelo Platform Owner em 2026-07-20 (DEC-25).** Lacuna de cobertura fechada — ver `KORTEXOS_5_1_2_DECISION_LOG.md`. Etapa 7 (Blueprint) segue desbloqueada por DEC-24, agora sem ressalva de cobertura pendente.

## 0. Por que este adendo existe

O Truth Map v1.0 (DEC-23) auditou os módulos 01–06 (DEC-20). D02 — Business Configuration & Policy Layer, e dentro dele a Calendar Policy & Availability Layer — não era um dos 6 módulos, então não foi auditado com a mesma disciplina de evidência. O Migration Map (DEC-24), ao mapear dependências do Availability Resolver (D07, em escopo), verificou o schema real e encontrou zero tabela correspondente a horário/turno/feriado — registrou isso como achado suplementar e recomendou este adendo antes do Blueprint tratar Availability como pronta para desenho. Este documento fecha essa lacuna de cobertura com a mesma disciplina do Truth Map original: evidência de código, não inferência.

## 1. Escopo auditado

Os 8 objetos de política do Master (Parte III §2.2) e a precedência de resolução de 7 níveis (§2.3): horário padrão da unidade, turnos por profissional, feriados, aberturas excepcionais, fechamentos excepcionais, folgas/férias, bloqueios pontuais, exceções pontuais.

## 2. Classificação da verdade atual

| Capacidade | Estado | Evidência física | Lacuna |
|---|---|---|---|
| Horário padrão da unidade | `AUSENTE` | `public.organizations` (`supabase/migrations/20260712235319_mvp_baseline.sql:11-18`) tem só `id`, `name`, `slug`, `active`, `created_at`, `updated_at` — nenhuma coluna de horário, nenhum `settings` JSONB, nenhuma tabela satélite | Não há como saber se um horário está "dentro do expediente" da unidade |
| Turnos por profissional | `AUSENTE` | `public.professionals` (`mvp_baseline.sql:125-136`) tem só `id`, `user_id`, `name`, `active`, timestamps — nenhum campo de jornada/turno | Master §2.4 marca "turno de staff ⊆ horário da unidade" como `CRÍTICO`; hoje não há nem o turno nem o horário da unidade contra o qual verificá-lo |
| Feriados / aberturas / fechamentos excepcionais | `AUSENTE` | Nenhuma tabela em nenhuma das 12 migrations; nenhuma referência em `backend/src/` ou `frontend/src/` (busca por `holiday`/`feriado`/`business_hours`/`opening_time`/`closing_time`/`working_hours`, case-insensitive: zero resultado) | Sistema não distingue dia útil de feriado — nenhuma regra impede agendar em data fechada |
| Folgas e férias | `AUSENTE` | Mesma busca acima, zero resultado | Idem |
| Bloqueios e exceções pontuais | `AUSENTE` | Mesma busca acima, zero resultado | Idem |
| Timezone da unidade | `AUSENTE` | `organizations` não tem coluna de timezone. `appointments.starts_at`/`ends_at` são `timestamptz` (`mvp_baseline.sql:171-172`) — armazenam instante absoluto corretamente, mas não há timezone de referência da unidade para exibição/cálculo de calendário | Master §2.4 marca isso `CRÍTICO` ("todo cálculo de calendário resolve no timezone da unidade") |
| Precedência de resolução (§2.3, 7 níveis) | `AUSENTE` | Não há motor nem dado — não existe o que a precedência resolveria | Consequência direta dos itens acima, não uma lacuna independente |
| Validação de horário no agendamento | `AUSENTE`, confirmado no código | `backend/src/modules/appointments/appointments.validation.js:26-35` (`validateDateTime`) só valida formato ISO 8601. A única proteção real é o exclusion constraint GiST em `appointments` (`mvp_baseline.sql:183-187`), que impede **sobreposição do mesmo profissional** — não valida se o horário está dentro de qualquer expediente, feriado ou turno | Confirmado: hoje é tecnicamente possível agendar às 3h de um domingo sem erro nenhum, desde que o profissional esteja livre naquele intervalo no banco |

## 3. Veredito

`CRÍTICO`/`AUSENTE` em toda a extensão do domínio auditado — não existe nem o dado (schema) nem a validação (código). É a lacuna mais completa encontrada em toda a auditoria 5.1.2 até agora: mais total até que o Availability Resolver (D07) em si, porque D07 ao menos tem a checagem de conflito por profissional como ponto de partida; a Calendar Policy não tem ponto de partida nenhum — nem uma coluna.

## 4. Impacto sobre a Ordem única de correção e o Migration Map

Não muda a ordem já desenhada — confirma e reforça a Onda 4 do Migration Map (`calendar_policies`, `professional_shifts`, já previstos). O que muda é a prioridade relativa: sem esses objetos, o Availability Resolver não tem política nenhuma para consumir e não pode ser prototipado com dado real, só com placeholder — risco concreto de o Blueprint cair em `MOCKADO` (proibido em fluxo crítico, §20.3 do Master) se tentar desenhar Availability antes de Calendar Policy existir.

## 5. O que este adendo NÃO muda

- Não altera o veredito geral do Truth Map v1.0 (`NO-GO` para produto final, DEC-23) — é uma confirmação mais granular de uma causa já apontada, não uma revisão.
- Não cria onda nova no Migration Map — a Onda 4 (DEC-24) já previa estes objetos; este adendo só formaliza a evidência que faltava.
- Não autoriza SQL, coluna, tipo ou constraint — mesma regra do Truth Map e do Migration Map que complementa.

## 6. Próximo passo executável ideal

1. ~~Platform Owner revisa este adendo~~ — **feito**: aprovado em 2026-07-20.
2. ~~Registrar DEC-25 fechando a lacuna de cobertura~~ — **feito**: `KORTEXOS_5_1_2_DECISION_LOG.md` atualizado; DEC-23 e DEC-24 não foram reabertas, só não cobriam D02 (fora do escopo original de ambos).
3. **Próximo:** o Blueprint (etapa 7) trata D02 Calendar Policy com a mesma prioridade da Onda 4, não como detalhe tardio — nenhuma cobertura pendente segue de pé.

---

FILES_CHANGED:
- `docs/KORTEXOS_5_1_2_TRUTH_MAP_ADENDO_D02.md`: novo (este documento).
- Nenhum arquivo de código, schema, migration ou teste foi alterado.

BLOCKERS_REMAINING:
- Todos os blockers já registrados em DEC-23/DEC-24 continuam abertos (não são resolvidos por este adendo).

VEREDITO:
- Cobertura de D02 (Calendar Policy & Availability Layer) fechada com evidência de código e APROVADA (DEC-25). `CRÍTICO`/`AUSENTE` confirmado em toda a extensão do domínio auditado — reforça, não contradiz, DEC-23/DEC-24. Nenhuma cobertura pendente bloqueia o início da etapa 7 (Blueprint).
