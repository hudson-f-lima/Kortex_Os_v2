# INSTRUÇÃO PARA CLAUDE CODE — KortexOS™ 5.1.2, Etapa 5: Truth Map

**Contexto:** você está recebendo 4 documentos canônicos, produzidos numa sessão longa de arquitetura no Claude (chat), que juntos formam a fonte única de verdade do KortexOS™ até este ponto:

1. `KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md` — regra vigente. Tese, domínios (D00–D31), motores, RAGOV, Gates, cadastros, configuração/onboarding/comanda/gorjeta/níveis.
2. `KORTEXOS_5_1_2_DECISION_LOG.md` — histórico completo de decisões (DEC-01 a DEC-22), padrão ADR, nunca editado, só marcado com status.
3. `KORTEXOS_5_1_2_GLOBAL_BENCHMARK_MAP.md` — benchmark rastreável por fonte dos módulos 01–06 (Booking, Waitlist, Checkout, Ledger, Compensation, No-show).
4. `KORTEXOS_5_1_2_COMPARATIVE_PROPOSAL.md` — 42 achados do benchmark classificados em HERDAR/RENOMEAR/REFORÇAR/BACKLOG/BLOQUEAR/DESCARTAR (DEC-22), incluindo 4 itens marcados **REFORÇAR CRÍTICO**: agendamento recorrente, cancelamento recorrente, Pix Automático, e resolução do hold de depósito.

Estes 4 arquivos são a ÚNICA fonte de verdade conceitual. Ignore qualquer versão anterior de Master Briefing, anexos A1/A2, ou instruções de sessões passadas que conflitem com eles.

---

## PASSO 0 — Verificação de identidade do repositório (fazer ANTES de tudo)

```text
Verificação parcial já feita fora desta sessão (via fetch estático, sem
execução de JS): https://hudson-f-lima.github.io/Kortex_Os_v2/ está
publicado, ativo, com título "KortexOS" e tema configurado (#141414).
Isso confirma: o repositório é genuíno, não é typo nem repo abandonado —
há pipeline de build/deploy funcionando via GitHub Pages.

O que NÃO foi possível verificar por fora (só você, com acesso ao código,
consegue): o fetch estático não executa JavaScript, então não é possível
saber se a aplicação por trás da casca da SPA está REAL, PARCIAL ou
MOCKADA. Isso é trabalho do Truth Map, não desta verificação prévia.

Antes de auditar código, responda:
1. Kortex_Os_v2 é a evolução/reescrita do repositório anterior
   (hudson-f-lima/HopeOs-v1, registrado em sessões passadas como o
   repositório do HOPE OS), ou um projeto paralelo/novo? Verifique
   histórico de commits, README, e se há menção a HopeOs-v1 no repo.
2. O diretório de trabalho local aponta para qual repositório como
   remote? (git remote -v)
3. Existe divergência entre local e GitHub? (git status, git log --oneline
   -5 local vs. remoto, branches não sincronizadas)

Reporte isso em texto claro ANTES de prosseguir para o Passo 1.
```

---

## PASSO 1 — Auditoria local × GitHub (higiene antes de auditar código)

```text
- git status: mudanças não commitadas?
- git log local vs. git log do remoto: commits locais não enviados,
  ou commits no GitHub não puxados localmente?
- Branches: qual branch é a fonte de verdade prática hoje?
- Se houver divergência real (não cosmética), reporte como achado do
  Truth Map — não corrija silenciosamente, decisão de merge/resolução é
  do Platform Owner (Eduardo), não automática.
```

---

## PASSO 2 — Truth Map (objetivo central desta sessão)

Etapa 5 da ordem de construção (Master Briefing §22.1). Objetivo: **classificar a realidade técnica atual do código**, domínio por domínio, contra o que os 4 documentos definem como regra vigente.

### 2.1 Escopo de prioridade

Auditar primeiro os 6 módulos com decisão já fechada no Comparative Proposal:

```text
01 Booking & Capacity Scheduling
02 Smart Gap / Waitlist / Resource Locks
03 Checkout & Payments
04 Ledger / Wallet / Current Accounts
05 Compensation / Tips / Payout
06 No-show / Deposit / Card-on-file
```

Dentro desses, priorizar os **4 itens REFORÇAR CRÍTICO** do Comparative Proposal (DEC-22) — são os que mais provavelmente NÃO existem ainda no código, por serem lacunas identificadas na revisão do Platform Owner, não apenas confirmações:

```text
- Agendamento recorrente (frequência configurável, série vs. ocorrência)
- Cancelamento recorrente (esta ocorrência vs. série inteira, com/sem aviso)
- Pix Automático (cobrança recorrente de plano via Banco Central)
- Resolução de hold de depósito (hold local + retentativa/lembrete
  próximo da data, em vez de depender de hold de rede de cartão)
```

Os outros 10 módulos (07–16) e os itens BACKLOG do Comparative Proposal **não entram nesta rodada** — não auditar fora do escopo priorizado (DEC-20 continua vinculante).

### 2.2 Taxonomia de classificação (usar exatamente esta, já padrão do produto)

| Classificação | Significado |
|---|---|
| REAL | Implementado, funcional, testado, sem gambiarra |
| PARCIAL | Existe, mas incompleto ou com lacuna conhecida |
| MOCKADO | Interface/contrato existe, lógica real não |
| HARDCODED | Valor fixo no código onde deveria ser configurável/calculado |
| CRÍTICO | Ausência ou erro aqui quebra integridade financeira/dados |

### 2.3 Formato de saída — modo de auditoria brutal (já padrão para HOPE OS)

```text
Resumo executivo
Gravidade econômica
Classificação da verdade atual (por domínio/módulo, tabela REAL/PARCIAL/
  MOCKADO/HARDCODED/CRÍTICO)
Falhas estruturais
Pontos cegos
Invariantes obrigatórios
O que congelar
Ordem única de correção
Patch list executável
Gates antes de expansão
O que não construir agora
Próximo passo executável ideal
```

---

## GUARDRAILS — o que esta sessão NÃO autoriza

```text
- NÃO escrever SQL, migration, schema novo.
- NÃO pular para Migration Map (etapa 6) ou Blueprint (etapa 7) — essas
  seguem BLOQUEADAS até o Truth Map estar concluído e revisado pelo
  Platform Owner.
- NÃO reescrever arquitetura já decidida nos 4 documentos — o Truth Map
  classifica realidade, não redesenha regra. Se encontrar código que
  contradiz uma decisão (ex.: DEC-11 reabertura de comanda, DEC-01
  absorção de taxa de gorjeta), reporte como FALHA ESTRUTURAL, não corrija
  direto sem aprovação.
- NÃO tratar achados do Global Benchmark Map ou Comparative Proposal como
  verdade de produto — são referência (RAGOV 20.4). A verdade de produto é
  o Master Briefing + o que o Truth Map encontrar no código real.
```

---

## Próximo passo após esta sessão

```text
1. Platform Owner revisa o Truth Map produzido.
2. Se aprovado: Master Briefing §22.1 atualiza etapa 5 para CONCLUÍDA,
   registra-se DEC-23 (ou próximo número livre) no Decision Log.
3. Segue para etapa 6 — Migration Map — só então.
```
