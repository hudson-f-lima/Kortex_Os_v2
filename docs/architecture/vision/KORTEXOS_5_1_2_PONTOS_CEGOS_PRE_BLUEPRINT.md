# KORTEXOS™ — Pontos Cegos Pré-Blueprint (Rodada 4)

**Versão:** v1.0
**Data:** 2026-07-20
**Produzido por:** Claude Code, em resposta ao pedido do Platform Owner: "nova rodada de Benchmark, levantamento de profundidade das camadas, procurar pontos cegos" — executado como leitura estrutural interna do Master Briefing (camadas §4.1, engines §12-19) + pesquisa externa (`KORTEXOS_5_1_2_GLOBAL_BENCHMARK_MAP.md`, RODADA 4).
**Escopo:** 5 pontos cegos, 4 com benchmark externo (Frentes A-D da Rodada 4) e 1 estrutural interno (D00, sem benchmark).
**Autoridade deste artefato:** identifica lacunas e propõe resoluções para aprovação — não decide sozinho, não altera DEC já registradas, não escreve SQL. Onde proponho uma resolução, está marcada **PROPOSTO** e aguarda seu sinal, no mesmo formato que resolveu os 4 riscos do Migration Map (DEC-24).
**Relação com artefatos existentes:** não invalida Truth Map (DEC-23), Migration Map (DEC-24) ou o adendo D02 (DEC-25) — aprofunda e, num ponto (seção 6), identifica uma tensão real com a Onda 4 do Migration Map que precisa de decisão explícita antes do Blueprint.
**Status:** **APROVADO pelo Platform Owner em 2026-07-20 (DEC-26).** As 7 resoluções propostas (seções 2, 3.1, 3.2, 4, 5.1, 5.2, 5.3) e o item de backlog D00 (seção 6) foram aprovados — ver `KORTEXOS_5_1_2_DECISION_LOG.md`. Etapa 7 (Blueprint) segue desbloqueada, agora com este material incorporado.

## 0. Origem e método

Pedido interpretado como: aprofundar as **camadas** já tocadas pela etapa 5/6 (Truth Map/Migration Map) antes do Blueprint travar decisões sobre elas — não uma nova rodada dos módulos 07-16 (esses continuam fora de escopo, DEC-20). Método: (1) releitura estrutural do Master Briefing nas seções ainda não auditadas a fundo (§4 camadas, §12-19 engines) cruzando contra o que Truth Map/Migration Map já cobriram; (2) 4 agentes de pesquisa em paralelo, mesma metodologia por Tier (DEC-21) das rodadas 1-3, cada um com fontes reais citadas.

## 1. Resumo executivo

O ponto cego mais profundo não veio do benchmark externo — veio da releitura interna: o Master define hierarquia `Sistema → Empresa → Unidade → Profissional` (§1.5, Parte III) como estrutural, e a palavra "unidade" aparece 22× no documento, mas **nenhuma tabela de unidade/filial existe no schema** — hoje `organizations` é um nível único, achatado. Isso é mais amplo que o gap de Calendar Policy já registrado em DEC-25: Calendar Policy é uma das camadas que *depende* de Unidade existir, e a Onda 4 do Migration Map (DEC-24) modelou `calendar_policies` como dependente de `organizations` diretamente — uma decisão que precisa ser revisitada à luz deste achado (seção 6).

Os outros 4 pontos cegos (Calendar Policy em profundidade, Action Request, Negative Guard/Reliability Score, D00 Platform Owner Layer) confirmam `AUSENTE` já esperado, mas cada um trouxe pelo menos uma divergência específica entre o que o Master especifica e o que o mercado realmente faz — não invalidam a arquitetura, mas são material real para o Blueprint, registrado aqui para não se perder.

## 2. Ponto cego 1 — Camada "Unidade" ausente (D01/D02/D28)

> **Nota de status (DEC-27, 2026-07-20):** a resolução PROPOSTA original desta seção (confirmar `organizations` = unidade de-facto, padrão Vagaro/Trinks) foi **reconsiderada** no mesmo dia — o Platform Owner optou pelo padrão Zenoti/Mindbody (`units` como entidade própria desde já). A análise e o benchmark abaixo continuam válidos como evidência; só a escolha final mudou. Ver `KORTEXOS_5_1_2_MIGRATION_MAP.md` v1.1, Onda 0, e `KORTEXOS_5_1_2_DECISION_LOG.md` DEC-27.

**Achado:** `organizations` (`supabase/migrations/20260712235319_mvp_baseline.sql:11-18`) é hoje o único nível de tenant. O Master pressupõe 2 níveis abaixo do Sistema (Empresa e Unidade) para toda a Business Configuration & Policy Layer (§1.3-1.6, Parte III) — inclusive Calendar Policy, já mapeada como `AUSENTE` em DEC-25.

**Benchmark (Frente A, ver Global Benchmark Map Rodada 4):** dois padrões de mercado legítimos, não um só. Zenoti/Mindbody/Boulevard criam a entidade Unidade/Center/Location desde o dia 1, mesmo para negócio single-location. Vagaro/Trinks tratam cada location como conta própria, vinculada depois só quando uma 2ª aparece — o negócio single-location nunca encontra o conceito. Nenhum player documenta publicamente uma camada Sistema→Empresa equivalente ao topo da hierarquia do Master.

**Tensão:** o Salão Esperança (contexto de referência do produto) é explicitamente single-location. D28 (Multiunit Enterprise) já está corretamente fora do escopo priorizado. Mas a Onda 4 do Migration Map (DEC-24) já modelou `calendar_policies` dependendo de `organizations` — uma decisão implícita pelo padrão Vagaro/Trinks (organização = unidade, por ora), tomada sem essa evidência de mercado disponível.

**PROPOSTO:** confirmar explicitamente o padrão Vagaro/Trinks como decisão consciente, não omissão — `organizations` continua sendo o de-facto "unidade" enquanto o negócio for single-location; `units` como tabela própria só entra quando D28 virar prioridade real (mesma régua de "básico antes do sofisticado" que já rege DEC-20). Isso **confirma** a Onda 4 do Migration Map como estava, mas exige uma nota explícita registrada (não silenciosa) de que essa é uma decisão de escopo, com o caminho de migração futura (retrofit de `units` vs. contas-pares) já mapeado por este benchmark para quando for necessário.

## 3. Ponto cego 2 — Calendar Policy, dois refinamentos (D02/D07)

Aprofundamento do que o adendo D02 (DEC-25) já classificou como `AUSENTE`. Dois achados específicos do benchmark (Frente B) que a Onda 4 do Migration Map não previu:

**3.1 — Precedência "abertura excepcional" vs. "fechamento excepcional" como dois níveis distintos.** Nenhum sistema pesquisado (nem os verticais, nem Dynamics 365/Oracle/Cal.com) separa isso em dois *tipos* de override com precedência fixa entre si — todos usam um único mecanismo genérico de override por data (abre OU fecha), desempatado por recência de edição, não por tipo. O Master (§2.3) trata como dois níveis hierárquicos fixos.

**PROPOSTO:** manter a intenção de proteção do Master (feriado não reabre por acidente), mas implementar como o Dynamics 365 faz — um único objeto "exceção pontual" com campo de tipo (aberto/fechado/horário customizado) e resolução por recência de edição dentro do mesmo nível de precedência, não dois níveis hierárquicos separados. Mesmo resultado de negócio, mecanismo mais simples e já provado em produção.

**3.2 — Objeto de pausa/intervalo ausente.** 100% dos players pesquisados (Zenoti shift duplo, Fresha até 10 blocos/dia, Vagaro até 4 blocos, Booksy breaks, Dynamics 365 com `WorkHourType` "Break" formal) modelam horário partido/pausa. Os 8 objetos de política do Master (§2.2) não incluem isso — só "Turnos (profissional)" no singular, sem especificar se permite múltiplos blocos por dia.

**PROPOSTO:** confirmar que `professional_shifts` (Onda 4, Migration Map) permite múltiplos registros por profissional/dia desde o desenho inicial — não é objeto novo, é uma característica do objeto já mapeado que precisa ficar explícita antes do Blueprint fixar "1 turno = 1 par início/fim" por engano.

## 4. Ponto cego 3 — Action Request: mecanismo ausente + padrão não previsto (D24/D31)

**Achado:** `AUSENTE` confirmado — nenhum módulo de aprovação/workflow existe no MVP. §19.2 do Master lista 13 ações que exigem Action Request (perdoar no-show, liberar fiado fora de política, ajustar comissão, criar crédito manual, ajustar contrato corporativo, entre outras).

**Benchmark (Frente C):** o Master só especifica o modelo assíncrono completo (draft→ready_for_review→approved→executing→executed). O mercado tem DOIS padrões, não um: dentro do nicho beauty-tech, o dominante é síncrono (PIN/senha do gerente no momento, sem objeto persistido — Zenoti, Vagaro, Square, Roller); fora do nicho, em fintech/core banking (Fineract, Ramp, Expensify), o padrão é assíncrono e arquiteturalmente idêntico ao que o Master já desenha ("comando persistido → aprovação de terceiro → execução do mesmo Command original, sem duplicar lógica").

**PROPOSTO:** manter o desenho assíncrono do Master como fundação (já validado por precedente real em produção, Fineract), mas explicitamente prever os dois modos sobre a mesma entidade: quando o aprovador está presente e tem a permissão, `draft`→`approved` colapsa numa interação só (equivalente a PIN, com motivo obrigatório — convergência achada em Zenoti/Boulevard/Ramp); quando não há aprovador presente, segue o ciclo assíncrono completo. Isso é registro para o Blueprint, não uma tabela nova — o Migration Map (DEC-24) ainda não tem uma onda dedicada a Action Request porque D24/D31 não estavam no escopo original; **recomenda-se que o Blueprint trate isso como pré-requisito das ações que a Onda 3 (Compensation) e a reabertura de comanda da Onda 6 já preveem** ("ajuste de comissão", "reabertura pós financial lock" — ambos da lista do §19.2).

## 5. Ponto cego 4 — Negative Guard / Client Reliability Score ausente (D16/D24)

**Achado:** `AUSENTE` confirmado — `clients` não tem nenhum campo de risco, score ou contador de falta.

**Benchmark (Frente D):** a régua de 4 degraus do Master (aviso → sinal 50% → pré-pagamento 100% → healing) não foi encontrada implementada e documentada em nenhum player de beauty-tech — pode ser diferencial genuíno ou padrão não documentado publicamente, não dá para descartar nenhuma hipótese. Dois achados específicos e acionáveis:

**5.1 — Variável ausente da lista do Master.** "Lead time" (antecedência do agendamento) é um dos preditores de no-show mais fortes e consistentes na literatura acadêmica de saúde — não está entre as 12 variáveis que o Master já lista (§11.3).

**PROPOSTO:** adicionar "antecedência do agendamento no momento da marcação" como 13ª variável considerada pelo Client Reliability Score.

**5.2 — Ambiguidade sobre eventos que pulam degrau.** Não fica claro no Master se um evento grave isolado (chargeback confirmado, fraude) pode saltar direto para pré-pagamento 100% sem esperar a "3ª falta" — a teoria de sanção graduada (Braithwaite) sugere que severidade deveria poder acelerar a escalada, e o próprio espírito do Negative Guard (§10, proteger margem/confiança proativamente) é consistente com isso.

**PROPOSTO:** explicitar que um evento classificado como `CRÍTICO` (chargeback confirmado, fraude comprovada) pode saltar diretamente ao degrau máximo da régua, independente da contagem de ocorrências prévias — regra de exceção, não a regra geral.

**5.3 — Escopo cross-tenant, decisão consciente a registrar.** OpenTable é o único player com reputação de cliente compartilhada entre negócios diferentes na mesma plataforma (mesmo assim em beta/opt-out). O Master, pela leitura do domínio D24 (escopado por organização em toda a especificação), não prevê isso.

**PROPOSTO:** confirmar explicitamente que o Client Reliability Score do KortexOS é escopado por organização, sem compartilhamento cross-tenant — consistente com a postura de privacidade já adotada em DEC-19/D26, e registrado como decisão consciente, não omissão a ser "corrigida" depois.

## 6. Ponto cego 5 — D00 Platform Owner Layer nunca auditado (achado interno, sem benchmark)

**Achado, sem pesquisa externa dedicada nesta rodada:** D00 "Platform Owner Layer — Operação platform, release, suporte, saúde de tenants" é o primeiro domínio da grade (§5), mas nunca apareceu em nenhuma auditoria até agora — não é um dos módulos 01-06 (DEC-20), não foi tocado pelo Migration Map. `backend/src/modules/` lista 19 módulos de negócio (appointments, checkout, orders, etc.) e nenhum módulo de administração de plataforma. Hoje, qualquer operação "dono da plataforma" (ver saúde de tenants, dar suporte, investigar produção) acontece por acesso direto a banco/infra, sem ferramenta própria — consistente com o que já está documentado em `docs/legacy/mvp-tecnico/PROJECT_STATE.md` (ex.: investigação de migration atrasada em produção foi feita via SQL direto, não por um painel).

**PROPOSTO:** não é urgente hoje (single-tenant real em operação, acesso direto é viável). Mas deve entrar explicitamente na fila de domínios do Migration Map como item de backlog nomeado — não ficar invisível — para quando o KortexOS operar múltiplos tenants pagantes reais e o acesso direto a banco deixar de ser uma prática segura ou escalável.

## 7. Tensão com o Migration Map já aprovado (DEC-24) — resolvida por DEC-27

Nenhum dos 5 pontos cegos invalida DEC-23, DEC-24 ou DEC-25. A camada Unidade (seção 2) tocava diretamente a Onda 4 do Migration Map, que havia modelado `calendar_policies`/`professional_shifts` como dependentes de `organizations`. **Resolvido em 2026-07-20 (DEC-27):** o Platform Owner optou por modelar `units` como tabela própria desde já (padrão Zenoti/Mindbody) — mais trabalho agora, mais correto a longo prazo, evita retrofit doloroso depois. `KORTEXOS_5_1_2_MIGRATION_MAP.md` v1.1 tem a Onda 0 (D01, `units`) e a Onda 4 revisada para depender dela.

Os demais achados (Calendar precedência/pausa, Action Request, Reliability Score) são refinamentos e adições de escopo dentro do que o Migration Map já mapeou — não mudam dependência nem "estende/novo" de nenhuma linha já aprovada, só adicionam detalhe que o Blueprint vai precisar.

## 8. O que isso NÃO é

```text
Não é uma nova etapa da ordem de construção — é aprofundamento das etapas 3/5/6
já concluídas, antes da etapa 7 (Blueprint) travar decisões sobre elas.
Não reabre ou invalida DEC-23/24/25.
Não autoriza SQL, coluna, tipo ou constraint.
Não é uma classificação HERDAR/REFORÇAR/BACKLOG/BLOQUEAR/DESCARTAR formal
(etapa 4) — os "PROPOSTO" acima são recomendações objetivas para aprovação
rápida, no mesmo formato que já resolveu os 4 riscos do Migration Map, não
uma nova rodada completa de Comparative Proposal.
```

## 9. Próximo passo executável ideal

1. ~~Platform Owner revisa os 7 itens marcados PROPOSTO e o item de backlog~~ — **feito**: aprovados em bloco em 2026-07-20.
2. ~~Registrar DEC-26 consolidando as resoluções~~ — **feito**: `KORTEXOS_5_1_2_DECISION_LOG.md` atualizado, sem reabrir DEC-23/24/25.
3. ~~Decisão sobre a seção 2 (Unidade)~~ — **feito**: confirmado o padrão Vagaro/Trinks (`organizations` = unidade de-facto por ora); a Onda 4 do Migration Map permanece como estava, agora com a decisão registrada explicitamente em `KORTEXOS_5_1_2_MIGRATION_MAP.md`.
4. **Próximo:** o Blueprint (etapa 7) segue como o próximo passo da ordem de construção, agora com este material de profundidade incorporado.

---

FILES_CHANGED:
- `docs/KORTEXOS_5_1_2_PONTOS_CEGOS_PRE_BLUEPRINT.md`: novo (este documento).
- `docs/KORTEXOS_5_1_2_GLOBAL_BENCHMARK_MAP.md`: RODADA 4 anexada (4 frentes, matriz rastreável por fonte).
- Nenhum arquivo de código, schema, migration ou teste foi alterado.

BLOCKERS_REMAINING:
- Todos os blockers já registrados em DEC-23/24/25 continuam abertos (não são resolvidos por este documento).

VEREDITO:
- 5 pontos cegos identificados, documentados com evidência (4 com benchmark externo citável, 1 estrutural interno) e as 7 resoluções + item de backlog APROVADOS (DEC-26). Nenhum invalidou o trabalho já aprovado; a decisão sobre Unidade confirma a Onda 4 do Migration Map como estava, agora registrada explicitamente. Blueprint (etapa 7) segue desbloqueado, agora incorporando este material.
