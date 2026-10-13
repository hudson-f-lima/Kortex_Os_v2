# KORTEXOS™ — Rodada 5: Benchmark Global + Cross-Industry e Auditoria de Lacunas

**Versão:** v0.2 — **PROPOSTA, não aprovada.**
**Data:** 2026-10-13
**Base verificada:** `staging` @ `ba0552e` (Ondas 0–6 implementadas em `staging`, 72 migrations, 23 módulos de backend, 9 de frontend). `main`/produção seguem na Fase 11 (INDEX).
**Changelog v0.1 → v0.2:** a v0.1 foi escrita sobre o estado de `main` (INDEX de 20/07: "Blueprint não iniciado") e **estava desatualizada**: `staging` já tem as Ondas 0–6. Além disso, a varredura da v0.1 só lia `KORTEXOS_5_1_2_*.md` e **não lia os ADRs nem os documentos de onda**, o que fez G-12 e G-18 parecerem mais ausentes do que são. Todas as lacunas foram reverificadas contra `staging` (ver §2, item 7, e os ajustes em G-06, G-11, G-12 e G-18).
**Natureza:** insumo para uma nova versão do Migration Map e para Blueprints corretivos. Mesma natureza do `GLOBAL_BENCHMARK_MAP`: **não é verdade de produto** (Master §20.4). Não escreve SQL, não define coluna/tipo, não cria domínio (o Master §5 proíbe domínio novo: tudo abaixo é evolução de D00–D31).
**Autoridade:** nenhuma decisão aqui vale sem DEC do Platform Owner. O número da DEC não é atribuído neste documento (o log já passou de DEC-68 e teve colisões de numeração).
**Classificação de evidência:** `FATO` (lido em fonte oficial/código) · `VENDOR` (afirmação do próprio fornecedor) · `TERCEIRO` (blog/diretório/agregador) · `INFERÊNCIA` (conclusão minha, sem fonte direta).

---

## 1. Resumo executivo

**Problema real.** A engenharia de núcleo avançou muito em `staging` (Units, Payment Core, Ledger, Compensation, Calendar Policy, Recorrência/Waitlist, Reabertura de comanda), mas **o caminho para colocar um segundo salão real em produção ainda tem buracos que nenhuma onda cobre**: não há como trazer os dados de quem usa outro sistema (o onboarding no código é só `POST /organizations`), não há escopo fiscal definido, a classificação legal do profissional (CLT × autônomo-parceiro) está registrada como pendência e nunca foi modelada, e não há MFA, política de backup/recuperação nem trilha de auditoria geral.

**Diagnóstico (causa, não sintoma).** O benchmark anterior cobriu 6 dos 16 módulos obrigatórios e a Rodada 4 os pontos estruturais; os módulos 07–16 e o Tier 2 (Uber, Aviação, Amazon, Apple, Disney) estavam "ainda não pesquisados". As ondas 0–6 foram desenhadas a partir desse recorte, então os buracos estão no que ele não olhou: **adoção (entrar no produto), conformidade (fiscal/trabalhista/LGPD) e confiança operacional (segurança/continuidade)**.

**Risco de sequenciamento (o ponto mais importante).** `staging` tem 72 migrations de núcleo financeiro e operacional, mas **nada disso chegou a produção** (INDEX: "nenhuma migration da trilha 5.1.2 chegou lá"; `main` bloqueado por gates e por `kortex-api-staging` suspenso por billing, DEC-40). Se a primeira promoção for feita sem importação, onboarding, escopo fiscal e MFA, o produto entra em produção forte por dentro e sem rampa de entrada. Os concorrentes brasileiros vendem *primeiro* configuração rápida, importação, nota fiscal e caixa. **INFERÊNCIA.**

**Veredito.** 4 lacunas **P0** (G-01, G-06, G-11, G-12; §4–§5) devem ser resolvidas *antes da primeira promoção a produção com um cliente real*. Diferente da v0.1, nenhuma exige reabrir Blueprint aprovado: são aditivas (forward-only) sobre as Ondas existentes, exceto G-12, que corrige um desenho que o próprio ADR 0005 deixou pendente.

---

## 2. Método e limitações (leia antes de confiar nos números)

1. **Varredura sistemática:** 56 capacidades candidatas × (a) documentos `KORTEXOS_5_1_2_*.md` e (b) `backend/src`, `frontend/src`, `supabase/migrations`. Cada "zero" relevante foi verificado manualmente por `grep` com contexto; a contagem bruta tem ruído (ex.: `split`, `tip`, `yield`, `meta` casam com usos alheios) e **não foi usada como prova**.
2. **"Nem pensado"** = 0 ocorrências relevantes em documentos e código. **"Pensado sem spec"** = aparece como nome/linha única, sem regra testável. **"Pensado, não construído"** = coberto por Truth Map/Migration Map (não repetido aqui).
3. **Fontes de mercado:** em sua maioria páginas de fornecedores e diretórios (viés de marketing). `trinks.com` e Capterra devolveram 403; vídeos de ajuda da Trinks não são legíveis; o portal do CashBarber não é legível. Onde a evidência é só de fornecedor, está marcado.
4. **Ausência em busca ≠ ausência no mercado.** Quando escrevo "não encontrei", é limite da busca, não prova.
5. **Cross-industry:** esta rodada cobre Aviação (IROPS), Saúde (previsão de no-show) e Hospitalidade/filas (waitlist de walk-in). **Uber, Amazon, Apple, Disney e Toyota seguem não pesquisados** — não afirmo nada sobre eles.
6. Nada aqui foi validado por advogado ou contador. Pontos legais estão marcados "validar".
7. **Erro da v0.1, corrigido:** a varredura leu só `docs/KORTEXOS_5_1_2_*.md`. Na v0.2 ela cobre todo `docs/` (exceto `legacy/` e este arquivo), incluindo ADRs, `waves/`, `reference/` e `architecture/`, e o código/migrations de `staging`. Quem consumiu a v0.1 (inclusive a descrição do PR) deve considerá-la superada.

---

## 3. Panorama de mercado relevante (o que foi efetivamente apurado)

| Referência | O que a evidência mostra | Força |
|---|---|---|
| **Trinks** (BR) | Central de ajuda com trilhas por segmento (salão, barbearia, clínica); categorias próprias de **Nota Fiscal**, **Conta Digital**, **Clube de Assinaturas**, **Estoque**, **Franquias e Redes**, **BI**, **IA**, **Treinamento ao vivo**; importação de clientes self-service; taxas de operadora pré-preenchidas. | FATO (índice da central de ajuda) |
| **Belasis** (BR) | Página dedicada a emissão de nota fiscal para salão; estoque fracionado; cashback; agendamento integrado a WhatsApp. | TERCEIRO/VENDOR |
| **Booksy** | Cadastro rápido, serviços pré-populados por categoria, marketplace; cobrança de 30% sobre 1ª visita no Boost com atribuição contestada (já no benchmark). | FATO/TERCEIRO |
| **Zenoti** | Baixa de insumo (backbar) **automática ao executar o serviço**, limiar mínimo por produto e por unidade, geração de pedido de compra, **custo de mercadoria por serviço → margem**; SOC 2 Tipo II / ISO 27001 reportados; papéis e permissões; recepcionista de IA que reagenda. | VENDOR + TERCEIRO |
| **Fresha** | AI Concierge (lançado em mai/2026, add-on ~US$ 99,95/mês/unidade, segundo diretório). Migração de dados *para* Fresha não encontrada; concorrentes descrevem migração *a partir* dela (clientes e serviços migram quase sempre; histórico e pagamentos frequentemente não). | TERCEIRO |
| **Phorest** | Fórmulas de coloração anexadas ao perfil do cliente via integração de terceiro (SalonScale); consentimento digital e fotos antes/depois em material de med spa. Se há campo nativo, **não confirmei**. | TERCEIRO |
| **Waitwhile / TablesReady / WELCOME** | Fila virtual de walk-in com SMS "seu profissional está pronto", check-in por QR/SMS, fusão de walk-in e agenda num só calendário. | VENDOR |
| **CashBarber** | Posicionado como gestão + mentoria, entrada assistida (consultoria), sem trial; detalhes de implantação não públicos. | FATO (home) |

**Cross-industry**

| Indústria | Padrão extraído | Aplicação ao KortexOS | Força / ressalva |
|---|---|---|---|
| **Aviação (IROPS)** | Quando o voo cai, o sistema **notifica, prioriza e reacomoda em lote** por regras de negócio (tier de fidelidade, classe tarifária, necessidades especiais, impacto de receita), com matriz de prioridade acordada. | Falta de profissional / fechamento da unidade → reacomodar a lista de clientes afetados por prioridade explicável (plano de assinatura, Reliability Score, serviço longo). | VENDOR (Sabre, IGT, Mphasis). Em salão, **não encontrei** ferramenta que automatize isso — **oportunidade de diferencial, não paridade**. |
| **Saúde** | Previsão de no-show serve para **direcionar** lembretes e overbooking; mas overbooking cria colisões e filas quando todos comparecem, e escores podem concentrar o custo em subgrupos (miscalibração) → exigir calibração por subgrupo. | Guardrails para encaixe/overbooking e para o Reliability Score (D24): calibrar, auditar viés, nunca bloquear sozinho. | Artigo revisado por pares (BMC 2024) + comentário (Ann Fam Med). **Sem ensaios randomizados encontrados**; "20–40% de redução" de blog é descartado como evidência. |
| **Hospitalidade/filas** | Fila virtual com notificação e check-in sem balcão. | Rodízio/walk-in (já lacuna registrada no Decision Log 8.3) e check-in. | VENDOR. |

---

## 4. Matriz de lacunas

Severidade: **P0** bloqueia entrada de cliente real ou força retrabalho de desenho já aprovado · **P1** necessário para competir/operar com qualidade · **P2** backlog.

### 4.A — Nem pensado (0 em documentos, 0 em código; verificado)

| ID | Capacidade | Evidência de mercado | Domínio | Sev. |
|---|---|---|---|---|
| G-01 | **Importação de dados de outro sistema** (clientes → serviços → histórico) com pré-visualização, relatório por linha e reversão por lote | Trinks: importação self-service na Etapa 1 (FATO). Concorrentes de migração: clientes migram quase sempre; histórico e pagamentos nem sempre (VENDOR). | D03/D05 | **P0** |
| G-02 | **Exportação / portabilidade** dos dados do titular e do tenant | LGPD art. 18, V (portabilidade) — leitura **a validar** com jurídico. Também é argumento de confiança (sem lock-in). | D26 | P1 |
| G-03 | **Duração real do atendimento** (início/fim reais) para calibrar durações e alimentar Smart Gap | Sem fonte externa nesta rodada. Surge de ADR 0011 (congela duração *agendada*) e do Smart Gap (que depende de duração fiel). | D08 | P1 `INFERÊNCIA` |
| G-04 | **Ficha técnica do cliente de salão:** fórmula de coloração, fotos antes/depois, consentimento de **imagem** (distinto do consentimento de saúde da DEC-19) | Phorest/SalonScale (TERCEIRO). Anamnese já existe no desenho; fórmula/foto/imagem **não**. | D05/D26 | P1 |
| G-05 | **Estoque operacional:** mínimo/ponto de reposição, pedido de compra, **consumo de insumo por serviço**, custo por serviço → margem | Zenoti (VENDOR). O MVP tem movimentação de estoque; a regra de consumo por serviço não existe. | D06 | P1 |
| G-06 | **Segurança e continuidade:** MFA, backup e **teste de restauração** com RPO/RTO definidos, SLOs/alertas | Zenoti: SOC 2/ISO 27001, RBAC, logs (VENDOR/TERCEIRO). Em `staging`: MFA 0 menções; backup só aparece como rota de rollback ("use restore de backup", ADR 0016) — **pressupõe backup, mas nenhuma política, RPO/RTO ou ensaio de restauração está definida**. | D00/D31 | **P0** |
| G-07 | Notificações push; automações por data (aniversário) | Mercado comum; D21 cobre canais mas não push/datas. | D21 | P2 |
| G-08 | Conciliação bancária (Open Finance), Tap to Pay/SoftPOS, conta digital própria | Trinks tem categoria "Conta Digital" (FATO). Conta digital implica regulação (BaaS) → **sofisticação prematura**; manter bloqueado. | D13/D14 | P2 |
| G-09 | **Canais externos de reserva:** Google, WhatsApp, Instagram | Trinks: "Agendamento pelo Google" e "por WhatsApp" (FATO); Booksy/Google (FATO). D20/D27 falam de marketplace, não destes canais. | D20/D27 | P1 |
| G-10 | Treinamento / customer success como canal de ativação | Trinks: agenda de treinamentos ao vivo (FATO). CashBarber: entrada por consultoria. | D03 | P2 |

### 4.B — Pensado, mas sem spec testável (um nome ou uma linha)

| ID | Capacidade | O que existe hoje | Evidência/risco | Dom. | Sev. |
|---|---|---|---|---|---|
| G-11 | **Fiscal / NFS-e** | D26 é uma linha ("NFS-e, LGPD, consentimentos, fiscal"). A Onda 6 reconhece `fiscal_emission` como **produtor futuro** de `order_financial_locks` e declara emissão fiscal fora de escopo: o *gancho* existe, o **escopo e a regra não**. | NFS-e Padrão Nacional: MEI obrigado desde 2023 para cliente PJ (TERCEIRO, fontes divergem sobre PF); **Simples Nacional (ME/EPP): 1º/09/2026 ou 1º/11/2026 conforme a fonte** (TERCEIRO). Hoje é 13/10/2026: **a obrigação ou já vigora ou está a semanas**. Trinks e Belasis têm nota fiscal como módulo (FATO/TERCEIRO). Validar com contador. | D26 | **P0** (decisão de escopo) |
| G-12 | **Salão-Parceiro (Lei 13.352/2016)** — classificação legal do profissional | **Reconhecido e deixado pendente:** o ADR 0005 afirma que "o schema atual não modela (a) a classificação legal do profissional (CLT vs. autônomo-parceiro com contrato válido)" e que, sem isso, "qualquer automação de reversão de comissão é uma aposta jurídica". A Onda 3 (`staff_levels`, `commission_sale_records`) foi implementada **sem** resolver isso; nenhuma migration em `staging` modela contrato/retenção de parceiro. | Pela lei (FATO, texto legal): salão **centraliza pagamentos**, **retém** sua cota e **os tributos e contribuições do profissional**; contrato **escrito, homologado pelo sindicato**, com percentual de retenção, obrigação de reter/recolher, periodicidade e rescisão com aviso ≥ 30 dias (art. 1º-A, §§ 2º, 3º, 8º, 10). Isso **não é comissão de empregado**: afeta o desenho de D17. Status de ADI no STF **não confirmado** — validar texto vigente. | D17 | **P0** |
| G-13 | Walk-in / rodízio / check-in | Registrado como lacuna (Decision Log 8.3), "entra na pauta". Sem objeto nem regra. | Waitwhile/TablesReady (VENDOR). Núcleo de barbearia. | D07/D08 | P1 |
| G-14 | Encaixe / overbooking | Uma linha ("encaixe governado por permissão"). | Saúde: overbooking só com previsão calibrada e guardrails (§3). | D07/D08 | P2 |
| G-15 | Reacomodação em lote quando falta profissional/unidade | Não existe. Calendar Policy (D02) e Action Request (D24/D31) são pré-requisitos. | Aviação (§3). Diferencial. | D07/D08/D21 | P1 |
| G-16 | Rebooking no checkout | "Rebooking pós-atendimento" P1 sem mecânica; D24 só cita o termo. | Fresha/Zenoti vendem rebooking por IA (VENDOR). | D24 | P1 |
| G-17 | LGPD — canal de direitos do titular | Há regra de anonimização (REAL no Master). **Sem** canal de pedido, SLA nem registro de atendimento. | LGPD art. 18 — validar. | D26 | P1 |
| G-18 | **Trilha de auditoria geral** (config/política, papel, exportação, financeiro) | **PARCIAL.** Existem `unit_access_audit_events` (append-only, Onda 0: unidade, vínculo, escopo e permissões), imutabilidade de `commission_sale_records` (Onda 3) e `order_financial_locks` (Onda 6). **Não há** trilha uniforme para alteração de configuração/política, de papel fora do escopo de unidade, nem para exportação de dados. | Estende o padrão da Onda 0; pré-requisito de G-06 e G-02. | D31/D15 | **P0 → P1** (reduzido: núcleo existe) |

### 4.C — Pensado e não construído
Em `staging` já estão implementadas, com Blueprint, evidência e red team, as Ondas 0 (Units), 1 (Payment Core, **PARCIAL**, correção forward-only DEC-38), 2 (Ledger), 3 (Compensation), 4 (Calendar/Availability), 5 (Recorrência/Grupo/Waitlist) e 6 (Reabertura de comanda, dark launch); a Onda 7 (drag/resize) está parcial. Seguem não construídos D03 (onboarding além de criar organização), D04, D19–D31 e o que o Truth Map/Migration Map ainda listam. **Estado de cada onda: fonte primária é `docs/INDEX.md` e `docs/waves/`; não duplicado aqui.** Nada disso está em `main`/produção.

### 4.D — Defeitos em código existente
| ID | Achado | Estado |
|---|---|---|
| F-01 | `vite.config.js` fixava `start_url: '/'`; no build do GitHub Pages (`base=/Kortex_Os_v2/`) o manifesto saía com `start_url` **fora** do `scope` (verificado em build real). Efeito no usuário depende do navegador (`INFERÊNCIA`: instalação/lançamento fora do app). | **CORRIGIDO** nesta rodada (§7). |
| F-02 | Defeitos de CI/CORS/base path do Truth Map v1.0 | **Já corrigidos** pela DEC-28 — reverificado em `deploy-pages.yml`, `render.yaml` e `vite.config.js`. Nada a fazer. |

---

## 5. Spec proposta (requisitos testáveis dos P0, no nível de produto — não é Blueprint)

> Cada item: **regra → critério de aceite → dependências → gate.** Nomes de objeto são *candidatos* para o Migration Map; **colunas, tipos e RLS pertencem ao Blueprint.** Todo objeto de negócio herda as invariantes do `AGENTS.md` (`organization_id`, RLS, FK tenant-safe, centavos inteiros, idempotência, escopo por unidade conforme DEC-28).

### SPEC-R5-01 — Importação de dados (G-01) · D03/D05
- **Regras:** (1) v1 importa **clientes e serviços** de CSV; histórico de atendimento/pagamento é fase 2 (e só como registro histórico, nunca recria comanda nem ledger). (2) Fluxo obrigatório: **pré-visualização → relatório por linha (aceita/rejeitada/duplicada + motivo) → confirmação → aplicação**. (3) Escrita usa os **mesmos Commands** do cadastro manual (write-path único, como o Business Onboarding). (4) Idempotente: reexecutar o mesmo arquivo não duplica. (5) Todo lote tem identificador e pode ser **revertido** enquanto os registros não tiverem sido usados. (6) **Consentimento nunca é inferido**: contato importado entra como "sem consentimento de campanha"; o tenant é controlador e o KortexOS é operador. (7) Limite de linhas e tamanho; validação de telefone/e-mail; sem execução de fórmulas de planilha (injeção CSV).
- **Aceite:** arquivo de 5.000 linhas com 3% de erros → relatório exato, nenhuma linha inválida gravada; reimportar o mesmo arquivo → 0 novos; reverter lote → registros somem se não usados e permanecem listados como "em uso" se usados; cliente de outro tenant nunca é afetado.
- **Depende de:** Business Onboarding Workflow (Parte III §3); `clients` existente. **Gate:** Blueprint D03 aprovado.

### SPEC-R5-02 — Classificação legal do profissional e Salão-Parceiro (G-12) · D17 (estende Onda 3)
- **Regras:** (1) Vínculo de profissional ganha **classificação legal** (ao menos: `colaborador` [CLT] e `parceiro` [Lei 13.352]) — exatamente a lacuna (a) que o ADR 0005 deixou pendente; o motor de comissão deve poder representar "**cota retida do salão**" além de "comissão". (2) Para `parceiro`, o sistema **registra** contrato (data, percentual de retenção, periodicidade, referência de homologação sindical, vigência) e **bloqueia repasse sem contrato vigente**. (3) O sistema **registra** os valores retidos de tributos/contribuições informados pelo contador — **não calcula tributo** na v1 (evita assumir responsabilidade fiscal). (4) Estorno de venda reverte a cota retida pelo mecanismo do ADR 0005, **agora condicionado à classificação**: para `colaborador`, vale a regra trabalhista descrita no ADR 0005 (só insolvência do comprador autoriza estorno de comissão); para `parceiro`, vale o contrato. (4b) Parceiro **sem contrato vigente** deve ser tratado como risco de reenquadramento em vínculo CLT (ADR 0005, item 2) e sinalizado. (5) Relatório de repasse do parceiro separado do de colaborador. (6) Privacidade financeira de staff (D17) preservada.
- **Aceite:** parceiro sem contrato vigente → repasse recusado com motivo; venda de R$ 200,00 com retenção contratual de 40% → R$ 80,00 de cota do salão + R$ 120,00 ao parceiro (centavos inteiros), reconstruíveis do ledger; estorno parcial reverte proporcionalmente.
- **Depende de:** Ledger (Onda 2) e Compensation (Onda 3), **ambas já em `staging`**. **Alerta:** a Onda 3 foi implementada e auditada sem essa classificação; portanto a correção é **forward-only e aditiva** (nova migration), e o ponto crítico é que `commission_sale_records` já é imutável (Onda 3, migration `…onda3_commission_sale_records_immutability`) — a classificação deve ser **congelada no registro de venda no momento do checkout**, nunca lida depois, ou o histórico muda de significado se o vínculo mudar. **Validar** com advogado/contador (texto vigente, ADI, regime tributário do parceiro).

### SPEC-R5-03 — Fiscal: decisão de escopo (G-11) · D26
- **Opções:** **(a)** apenas *registrar* número, série e link/PDF da nota emitida fora do KortexOS, vinculados à comanda; **(b)** emitir via provedor/ERP integrado ao padrão nacional; **(c)** não tratar fiscal.
- **Recomendação:** **(a) agora, (b) como fase seguinte.** Menor custo, reversível, não cria obrigação de emissão que o produto ainda não suporta, e fecha a lacuna de conciliação nota↔comanda. (c) é incompatível com ME/EPP do Simples no prazo informado (validar).
- **Aceite de (a):** comanda fechada aceita referência fiscal; relatório lista comandas sem nota; edição da referência gera evento de auditoria.
- **Gate:** decisão do Platform Owner **com parecer de contador** antes do Blueprint de D26.

### SPEC-R5-04 — Baseline de segurança e continuidade (G-06, G-18) · D00/D31
- **Regras:** (1) **MFA obrigatório** para `owner` e `manager` (opcional para os demais); (2) **generalizar o padrão de `unit_access_audit_events`** (append-only, Onda 0) para os eventos ainda sem trilha: alteração de configuração/política, mudança de papel fora do escopo de unidade e exportação de dados (movimento financeiro já tem imutabilidade nas Ondas 3 e 6); (3) **backup com teste de restauração agendado** e resultado registrado; (4) **RPO/RTO definidos pelo Platform Owner** (não proponho número sem conhecer o plano do provedor e o custo); (5) alertas básicos de disponibilidade da API.
- **Aceite:** conta `owner` sem segundo fator não acessa financeiro; evento de auditoria não pode ser alterado nem apagado pelo `service_role` da aplicação; restauração de teste em ambiente descartável recupera estado ≤ RPO; ensaio registrado.
- **Verificar antes:** suporte a MFA e PITR no plano atual do provedor (não verificado).

### SPEC-R5-05 — Business Onboarding revisado (herda a comparação Booksy/Trinks) · D03
- Acrescentar ao fluxo canônico: **importação de clientes** (SPEC-R5-01), **lembretes transacionais** (confirmação/lembrete, separados de campanhas e consentimento), **agendamento de teste fechado até a comanda** como gate do checkout, e **taxas de adquirente com valores sugeridos exigindo aceite explícito**.
- Mantida a hipótese *não validada* de etapa 1 leve (CNPJ diferido) até o parecer fiscal (SPEC-R5-03).

### Itens P1 (spec resumida, sem prioridade de Blueprint imediata)
| Spec | Essência | Critério de aceite resumido |
|---|---|---|
| R5-06 Walk-in/check-in (G-13) | Fila virtual por unidade, check-in por QR, notificação "profissional pronto", regra de rodízio configurável | cliente sem agendamento entra na fila e é chamado pela regra; walk-in e agenda no mesmo calendário |
| R5-07 Duração real (G-03) | `início_real` e `fim_real` por atendimento, **sem** efeito em pagamento/comissão na v1 | relatório de duração real × agendada por serviço/profissional |
| R5-08 Estoque operacional (G-05) | Regra de consumo por serviço, mínimo por produto/unidade, alerta, pedido de compra manual; custo por serviço | serviço concluído baixa insumo configurado; abaixo do mínimo gera alerta |
| R5-09 Ficha técnica (G-04) | Campos de fórmula, galeria de fotos, **consentimento de imagem separado** do de saúde | foto sem consentimento de imagem não é armazenada; revogação remove acesso |
| R5-10 Reacomodação em lote (G-15) | Ao indisponibilizar profissional, listar afetados por **prioridade explicável**, propor alternativas, **exceção financeira via Action Request** | nenhum cliente é movido sem confirmação ou regra registrada |
| R5-11 Canais externos (G-09) | Reserva a partir de Google/WhatsApp entrando como *booking intent* (nunca confirma direto) | intenção externa sempre passa pelo Command de agendamento |
| R5-12 Rebooking no checkout (G-16) | Oferta de próximo horário ao fechar a conta, respeitando política de benefício | oferta registrada e conversão rastreável com origem |
| R5-13 LGPD titular (G-17) / Export (G-02) | Canal de pedido, prazo, registro, exportação estruturada | pedido atendido e auditado dentro do prazo configurado |

---

## 6. Sequenciamento recomendado

1. **Antes da primeira promoção a `main`/produção com cliente real:** SPEC-R5-02 (classificação legal do profissional, hoje pendência aberta do ADR 0005) e SPEC-R5-04 (MFA, política de backup/restauração, e extensão da trilha de auditoria).
2. **Antes de um 2º cliente real:** SPEC-R5-01 (importação), SPEC-R5-03 (decisão fiscal) e SPEC-R5-05 (onboarding revisado).
3. **Depois:** P1 na ordem de valor para o piloto (barbearia/salão): R5-07, R5-06, R5-08, R5-09, R5-12.
4. **Congelar:** G-08 (conta digital/SoftPOS) e o que depender de Uber/Amazon/Apple/Disney, até esses benchmarks existirem.

**Objetos candidatos para o Migration Map** (nomes provisórios; sem coluna/SQL): `import_batches`, `partner_contracts`, `fiscal_document_refs`, `audit_events`, `walkin_queue_entries`, `service_consumption_rules`, `stock_policies`, `client_technical_records`, `client_media_consents`. `audit_events` é candidato a **generalizar** `unit_access_audit_events` (Onda 0), não a duplicá-lo. Classificação de escopo por unidade a decidir no Blueprint, seguindo o padrão da DEC-28. A numeração de ondas corretivas fica para o Migration Map (a versão vigente em `docs/waves/` é a v1.3).

---

## 7. Correção executada nesta rodada

| Arquivo | Mudança | Verificação |
|---|---|---|
| `frontend/vite.config.js` | `start_url` passa a derivar do mesmo `basePath` do `base` (antes `'/'` fixo) | Build com `VITE_BASE_PATH=/Kortex_Os_v2/` → `start_url` e `scope` = `/Kortex_Os_v2/`. Build sem variável → ambos `/`. `npm run lint`: 0 erros (1 *warning* pré-existente em outro arquivo). `vitest`: 106/106. |

**Não executado, de propósito:** SQL, migrations, tabelas, endpoints e telas novas. O `AGENTS.md` condiciona domínio/tabela/endpoint à aprovação de Blueprint e SQL por etapa; esta rodada é anterior a ambos.

---

## 8. Decisões que preciso do Platform Owner

1. Aprovar (ou ajustar) esta Rodada 5 como insumo, registrando a DEC.
2. Autorizar uma **nova versão do Migration Map** com os objetos candidatos da §6, e **Blueprints corretivos** (forward-only) começando por SPEC-R5-02 e SPEC-R5-01. Cada Blueprint segue o gate próprio; SQL (Etapa 8) só depois.
3. Escolher a opção fiscal (a/b/c) **depois do parecer de um contador**.
4. Definir RPO/RTO e se MFA obrigatório para `owner`/`manager` é aceitável para o piloto.
5. Confirmar se o piloto (Salão Esperança) tem profissionais em regime de parceria — isso define a urgência real de SPEC-R5-02.
6. Autorizar a pesquisa do Tier 2 restante, ou formalizar que ele permanece fora de escopo.

---

## 9. Fontes

- Trinks — [central de ajuda](https://ajuda.trinks.com), [trilha salão](https://ajuda.trinks.com/trilha-para-salao), [trilha barbearias](https://ajuda.trinks.com/trilha-para-barbearias), [formas de pagamento](https://ajuda.trinks.com/formas-de-pagamento), [treinamentos](https://ajuda.trinks.com/treinamento-trinks?hsLang=pt-br)
- Booksy — [Get Discovered in 6 Steps](https://biz.booksy.com/blog/get-discovered-on-booksy-in-6-simple-steps), [Booksy BR](https://biz.booksy.com/pt-br/por-que-o-booksy)
- Zenoti — [Inventory Management](https://www.zenoti.com/salon-management-software/inventory-management), [Security](https://www.zenoti.com/trust/security), [best salon software 2026](https://zenoti.com/thecheckin/best-salon-management-software-2026)
- Fresha / Zenoti IA — [Fresha AI Concierge (diretório)](https://www.stork.ai/en/fresha-ai-concierge), [Zenoti AI receptionist (diretório)](https://www.stork.ai/pt/zenoti-ai-receptionist)
- Migração entre sistemas — [salonMonster](https://help.salonmonster.com/hc/salonmonter-help-and-guides/articles/1757567763-moving-from-fresha-to-salon_monster), [Mangomint](https://www.mangomint.com/go/switch-from-fresha/), [SchedulingKit](https://schedulingkit.com/migrate-from/fresha)
- Phorest/cor — [SalonScale × Phorest](https://www.salonscale.com/en-us/post/phorest-salonscale-integration-connect-appointments-colour-tracking-and-checkout)
- Walk-in — [Waitwhile](https://waitwhile.com/salon-waitlist), [TablesReady](https://tablesready.com/industry/salon-appointment-software), [WELCOME by SalesVu](https://apps.apple.com/us/app/welcome-by-salesvu/id1312855137?ls=1)
- Salão-Parceiro — [Lei 13.352/2016 (Senado)](https://legis.senado.leg.br/norma/602577/publicacao/15652949), [Câmara](https://www2.camara.leg.br/legin/fed/lei/2016/lei-13352-27-outubro-2016-783851-publicacaooriginal-151331-pl.html)
- NFS-e — [ContaAzul](https://contaazul.com/blog/nfse-padrao-nacional/), [Contmatic](https://simplifique.contmatic.com.br/blogs/nfse-nacional-obrigatoria-setembro-2026), [FocusNFe](https://focusnfe.com.br/blog/nfse-nacional/), [Belasis](https://www.belasis.com.br/en/emissao-de-nota-fiscar-salao-de-beleza)
- Aviação — [American Airlines IROPS](https://saleslink.aa.com/en-US/resources/html/irregular-operations-irops.html), [IGT Solutions](https://igtsolutions.com/?p=1760)
- Repositório (`staging` @ `ba0552e`) — `docs/architecture/adr/0005-reversao-de-comissao-em-estornos.md`, `docs/architecture/adr/0016-onda0-units-architecture.md`, `docs/waves/onda-0-units/KORTEXOS_5_1_2_BLUEPRINT_ONDA_0.md`, `docs/waves/onda-3-compensation/KORTEXOS_5_1_2_BLUEPRINT_ONDA_3.md`, `docs/waves/onda-6-checkout-reopen/BLUEPRINT_ONDA_6.md`, `docs/INDEX.md`
- Saúde — [BMC Health Serv Res 2024](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10770919/), [Annals of Family Medicine](https://www.annfammed.org/node/27248)
