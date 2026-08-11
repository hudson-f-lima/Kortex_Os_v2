---
target: frontend/src/modules/caixa/CaixaPage.jsx
total_score: 23
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 3
timestamp: 2026-08-11T10-31-47Z
slug: frontend-src-modules-caixa-caixapage-jsx
---
Method: dual-agent (A: ad0dd6d2dd2d86d6f · B: a7dd4ced9bd1f1bf4), rodado em worktree isolado (`fix/caixa-critique-p0-p2-and-design-docs` em commit `a4775f9`), sem contaminação do diretório de trabalho principal.

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 2 | `load()` sempre dispara skeleton de página inteira — troca de filtro ou pós-envio apaga toolbar+título, não só a lista |
| 2 | Match System / Real World | 3 | pt-BR correto e específico, mas ainda não existe o "modelo mental de caixa" (abrir/fechar, esperado vs. contado) |
| 3 | User Control and Freedom | 2 | Modal sai limpo, mas sem "limpar filtros" num clique e sem affordance de corrigir/anular um lançamento já enviado |
| 4 | Consistency and Standards | 3 | Construído 100% com primitivos; mas 2 hex diferentes pro mesmo "vermelho de perigo", e mismatch label/aria-label no filtro de data |
| 5 | Error Prevention | 3 | Preview "Confirma R$ X" continua sólido, específico do domínio |
| 6 | Recognition Rather Than Recall | 3 | Select "Tipo" sem label visível, só aria-label |
| 7 | Flexibility and Efficiency | 1 | Sem atalho, sem preset "Hoje", sem ação em lote — mesmo gap do ciclo anterior |
| 8 | Aesthetic and Minimalist Design | 3 | `<h1>` sem estilo pesa mais visualmente que `.caixa-total`, o número que realmente importa |
| 9 | Error Recovery | 2 | Mensagens de erro de campo são boas; mas a negação de acesso pra recepção é um beco sem explicação |
| 10 | Help and Documentation | 1 | Nenhuma ajuda contextual em tela com consequência financeira real |
| **Total** | | **23/40** | **Aceitável** |

Todas as 10 heurísticas foram pontuadas (nenhuma n/a). **Evolução: 15/40 (Ruim) → 23/40 (Aceitável), +8 pontos.**

Carga cognitiva: **1 falha** (baixa/boa) — evolução de 3 falhas (moderada) no ciclo anterior.

## Design Specificity Verdict

**LLM assessment**: A lógica de negócio segue genuinamente específica do domínio (líquido com sinal corretamente comentado, centavos inteiros, Idempotency-Key, preview de valor específico contra o truncamento silencioso do `reaisToCents`). Mas **a composição continua sendo o shell genérico de lista verbatim** — `styles.css` agrupa `.caixa-page` literalmente na mesma regra que `.clientes-page, .equipe-page, .catalogo-page, .estoque-page, .organizacao-page`, e o padrão toolbar→total→lista é indistinguível de um cadastro de equipe ou estoque. Nada da linguagem "Control Room" do próprio `DESIGN.md` (glanceability de status, a barra colorida de 4px) aparece aqui. Sessão de caixa (abrir/fechar, o momento de "control room" de verdade) segue fora de escopo deste arquivo, confirmado por comentário em `RefundModal.jsx`.

**Deterministic scan**: `detect.mjs --json` limpo nas duas rodadas (arquivo e diretório), exit 0, mesmo resultado do ciclo anterior — confirma que esse tipo de achado estrutural/semântico segue fora do alcance do detector.

**Visual overlays**: `/caixa` bloqueado por autenticação de novo (esperado, sem credenciais tentadas). Mecanismo de injeção confirmado funcionando contra a tela de login (única alcançável) — `1 anti-pattern found` no ciclo anterior nessa mesma tela virou `No anti-patterns found` agora, o que bate com o fix de contraste do login já aplicado nesta sessão. Nenhuma evidência visual renderizada de `CaixaPage.jsx` em si.

## Overall Impression

Progresso real e mensurável — os 2 P0 do ciclo anterior (total sem sinal, sem distinção visual entrada/saída) não aparecem mais como P0 porque foram corrigidos. Mas a correção do segundo criou um problema novo: o verde usado pra marcar "entrada" **não passa no contraste mínimo AA** contra fundo branco — um número que o time olha dezenas de vezes por turno. Fora isso, os gaps estruturais do ciclo anterior (sem atalho de "hoje", busca sem paginação, hierarquia visual invertida entre título e saldo) continuam intactos porque nunca foram escopo dos fixes.

## What's Working

1. **Prevenção de erro específica do domínio.** `ManualEntryModal.jsx:32-36` mostra "Confirma R$ X" ao vivo antes de enviar, defendendo especificamente contra o truncamento silencioso do `reaisToCents` — um detalhe que um formulário CRUD genérico não teria.
2. **Matemática financeira correta e defensivamente comentada.** `CaixaPage.jsx:98-103` líquida débito contra crédito com comentário descrevendo o bug real que substituiu; cada linha do extrato tem sinal, cor e Badge distintos.
3. **RBAC espelhado e testado ponta a ponta.** Os gates de leitura/escrita apontam pro exato ponto de verdade no backend via comentário, e os caminhos de permissão e negação têm teste dedicado.

## Priority Issues

**[P1] Skeleton de página inteira substitui a tela toda em todo refetch, não só no primeiro load**
- **Por que importa**: trocar o filtro "Tipo", ou completar um lançamento manual com sucesso, apaga `h1`, toolbar e filtros junto com a lista — pro atendente com cliente esperando, isso lê como o app reiniciando, bem no momento (pós-lançamento financeiro) em que reassurance importa mais.
- **Fix**: manter a toolbar montada durante refetches; travar o loading só no corpo da lista, reservar `PageSkeleton` pro primeiro paint de verdade.
- **Suggested command**: `$impeccable polish`

**[P1] Verde do valor de crédito não passa no contraste mínimo AA — regressão introduzida pelo próprio fix desta sessão**
- **Por que importa**: `.record-amount--credit { color: var(--color-success) }` = `#059669` sobre branco ≈ **3.77:1**, abaixo do mínimo AA (4.5:1) pro tamanho do texto (13.6px), e bem abaixo do piso AAA que o próprio `DESIGN.md`/`AGENTS.md` declaram como invariante do projeto (7:1), não meta aspiracional. Confirmado por cálculo independente (luminância relativa WCAG), não só pelo relato do agente.
- **Fix**: usar um tom mais escuro (`emerald-700 #047857`, ≈5.9:1 — ainda não bate AAA) ou parear com fundo tintado como o `Badge` já faz, em vez de texto direto sobre branco.
- **Suggested command**: `$impeccable audit`

**[P1] Nome acessível não bate com o label visível nos filtros de data (WCAG 2.5.3)**
- **Por que importa**: `aria-label="Data inicial"`/`"Data final"` sobrescreve o nome acessível dos campos rotulados visualmente "De"/"Até" — usuário de comando de voz dizendo "clique em De" não encontra nada. Já constava no ciclo anterior (Persona Sam), nunca corrigido.
- **Fix**: remover o `aria-label` redundante (o `label` visível já monta `<label htmlFor>` correto).
- **Suggested command**: `$impeccable audit`

**[P2] Sem intervalo de data padrão; busca de "período" é cosmética sobre um fetch sem limite**
- **Por que importa**: toda abertura de página, troca de filtro ou refetch pós-envio puxa o histórico inteiro de lançamentos da organização antes de recortar visualmente — fica mais lento a cada mês de operação, e agrava o flash de skeleton no dispositivo (tablet, wifi de salão) menos preparado pra esconder a demora. Já constava no ciclo anterior (Persona Riley), nunca corrigido.
- **Fix**: `fromDate`/`toDate` default "hoje", mandar limites de data pro backend, paginação real pra consultas de histórico completo.
- **Suggested command**: `$impeccable harden`

**[P2] "Seu papel não pode visualizar o caixa" é beco sem saída alcançado por um item de nav que promete acesso**
- **Por que importa**: `nav.js` lista "Caixa" pra recepção mesmo com `READ_ROLES`/`WRITE_ROLES` excluindo esse papel — a pessoa fisicamente mais perto do caixa vê o item, clica, e esbarra numa parede sem explicação nem próximo passo.
- **Fix**: remover "Caixa" da nav da recepção (se for regra intencional), ou dar à mensagem de negação uma ação concreta.
- **Suggested command**: `$impeccable clarify`

## Persona Red Flags

**Sam (Accessibility-Dependent User)**: os dois achados de contraste/rótulo acima (verde AA-fail, mismatch label/aria-label) são ambos em conteúdo central da tela, não decoração.

**Riley (Deliberate Stress Tester)**: sem `.limit()`/`.range()` em nenhum lugar do serviço de cash-entries no backend — busca sem paginação de verdade. `.caixa-total` não tem nenhuma propriedade de cor, então um "Saldo do período" negativo (mais saída que entrada) renderiza em tinta preta idêntica a um saldo saudável — nenhum alarme visual pro cenário que mais importa detectar.

**Casey (Distracted Mobile User)**: todo lançamento manual — a ação mais repetida da tela — dispara o flash de skeleton de página inteira, pior exatamente no dispositivo/rede da Casey (tablet, wifi de salão, fetch sem limite). `.record-list-item` usa `flex-wrap: wrap`, então badge/valor/meta podem quebrar de forma estranha numa viewport estreita com cliente olhando.

## Minor Observations

- Dois hex literais diferentes pro mesmo "vermelho de perigo": `.form-error` usa `#b3261e`, o token do design system é `--color-danger: #DC2626`.
- `<h1>Caixa</h1>` não recebe nenhum tratamento CSS — renderiza no tamanho padrão do browser, brigando com a hierarquia que `.caixa-total` deveria ter. Sistêmico (toda página de lista faz o mesmo), não exclusivo do Caixa.
- Empty state é um `<p className="list-empty">` simples em vez do primitivo `EmptyState` mais rico que `ClientesPage`/`CatalogoPage` usam.
- `ToastProvider` está montado na raiz do app mas `useToast`/`showToast` não é chamado em lugar nenhum do código — inclusive nesta tela de dinheiro, que não dá nenhuma confirmação de sucesso após enviar um lançamento.
- `KIND_OPTIONS` do filtro mistura tipos gerados pelo sistema (`sale`, `refund`) com os criáveis manualmente (`income`, `expense`) sem distinção visual de origem nas linhas da lista.

## Questions to Consider

- Se um atendente acabou de registrar um lançamento com cliente esperando, por que mostrar a nova linha exige re-buscar e re-renderizar a própria toolbar e o título da página do atendente?
- O norte criativo "Control Room" do `DESIGN.md` é construído sobre glanceability instantânea de estado — por que o número mais consequente da tela (`Saldo do período`) tem peso visual menor que o título da página?
- Recepção aparece na navegação do Caixa e depois é barrada por completo, sem dado nenhum e sem explicação — "só gestão mexe no caixa" é a regra real pretendida? Se for, o item de nav não deveria simplesmente não aparecer pra recepção, em vez de aparecer e negar?
- Dado que esta tela é aberta e reconsultada muitas vezes por turno, como seria um desenho em volta de "hoje" como visão padrão e um fluxo de lançamento em velocidade de teclado numérico, em vez da mesma casca lista-toolbar-modal usada pro cadastro de equipe e pro catálogo de estoque?
