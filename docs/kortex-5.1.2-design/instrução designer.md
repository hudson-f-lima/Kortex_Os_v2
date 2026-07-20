# Prompt técnico — Implementação da nova interface KortexOS no repositório

Use este prompt em um agente de desenvolvimento com acesso integral ao repositório `Kortex_Os_v2` e ao documento `Kortex_Design_System_v1_0.docx`.

```text
Você atuará como Staff Front-end Engineer, Design Systems Engineer, Product Designer e QA Engineer responsável por implementar a nova interface do KortexOS no repositório existente.

OBJETIVO

Transformar o front-end atual do KortexOS em uma interface operacional premium, humana, responsiva e consistente, seguindo:

- estética Apple humana;
- Bento Grid operacional;
- verde-esmeralda como cor de ação e resultado;
- azul-royal como cor de inteligência e informação;
- alta densidade operacional;
- navegação adaptativa por dispositivo;
- Agenda como principal superfície do produto;
- Design System canônico;
- acessibilidade WCAG 2.2 AA;
- boa performance percebida e real.

A implementação deve respeitar integralmente o Kortex Design System v1.0, especialmente:

- Desktop: Sidebar + Topbar;
- Tablet paisagem: Navigation Rail + Topbar;
- Tablet retrato: Topbar + Bottom Navigation;
- Mobile: Topbar + Bottom Navigation;
- barra inferior no desktop apenas quando contextual;
- calendário mensal fechado por padrão;
- Agenda ocupando aproximadamente 75% a 80% da altura útil;
- Bento Grid apenas em superfícies de síntese;
- verde-esmeralda para ações e resultados;
- azul-royal para inteligência, informação e foco;
- uma única App Shell adaptativa;
- componentes canônicos obrigatórios.

O documento Kortex Design System v1.0 é a fonte de verdade visual e comportamental. :contentReference[oaicite:0]{index=0}

PRINCÍPIOS NÃO NEGOCIÁVEIS

1. Não reescrever o projeto inteiro.
2. Não trocar framework sem necessidade comprovada.
3. Não quebrar rotas, autenticação, autorização ou contexto organizacional.
4. Não misturar refatoração visual com alterações desnecessárias de domínio.
5. Não criar componentes locais quando existir componente canônico equivalente.
6. Não espalhar valores de cor, radius, espaçamento, sombra ou motion pelo código.
7. Não criar três aplicações separadas para desktop, tablet e mobile.
8. Não copiar visualmente nenhuma referência externa.
9. Não priorizar decoração acima da operação.
10. Não considerar a tarefa concluída apenas porque o build passou.

RESULTADO ESPERADO

Ao final, o repositório deverá possuir:

1. Design System implementado.
2. App Shell responsiva.
3. Home “Hoje” em Bento Grid.
4. Agenda refatorada.
5. Navegação consistente.
6. Componentes reutilizáveis.
7. Estados de loading, vazio, erro, offline e sucesso.
8. Testes básicos de interface e responsividade.
9. Documentação técnica da implementação.
10. Relatório de alterações, riscos e pendências.

FASE 0 — INSPEÇÃO ANTES DE ALTERAR

Antes de modificar qualquer arquivo:

1. Mapear a estrutura atual do front-end.
2. Identificar:
   - entry point;
   - App;
   - rotas;
   - contexts;
   - páginas;
   - módulos;
   - componentes compartilhados;
   - estilos;
   - Service Worker;
   - PWA;
   - assets;
   - testes;
   - dependências.
3. Executar:
   - instalação;
   - build;
   - lint;
   - testes existentes.
4. Registrar:
   - estado inicial;
   - erros;
   - warnings;
   - arquivos críticos;
   - riscos de regressão.
5. Identificar o menor caminho seguro para implementação incremental.

Não alterar código antes de produzir esse inventário.

FASE 1 — CRIAR A ESTRUTURA DO DESIGN SYSTEM

Criar ou adaptar:

frontend/src/
├── app/
│   ├── AppShell.jsx
│   ├── DesktopSidebar.jsx
│   ├── NavigationRail.jsx
│   ├── MobileTabBar.jsx
│   ├── TopBar.jsx
│   ├── ContextualActionBar.jsx
│   └── routes.js
│
├── ui/
│   ├── foundations/
│   │   ├── reset.css
│   │   ├── tokens.css
│   │   ├── theme-light.css
│   │   ├── theme-dark.css
│   │   ├── typography.css
│   │   ├── motion.css
│   │   └── utilities.css
│   │
│   ├── primitives/
│   │   ├── Button.jsx
│   │   ├── IconButton.jsx
│   │   ├── Input.jsx
│   │   ├── Select.jsx
│   │   ├── Card.jsx
│   │   ├── Surface.jsx
│   │   ├── Badge.jsx
│   │   ├── Avatar.jsx
│   │   ├── Divider.jsx
│   │   ├── Tooltip.jsx
│   │   ├── Skeleton.jsx
│   │   └── Progress.jsx
│   │
│   ├── patterns/
│   │   ├── PageHeader.jsx
│   │   ├── FilterBar.jsx
│   │   ├── EmptyState.jsx
│   │   ├── StatCard.jsx
│   │   ├── BottomSheet.jsx
│   │   ├── Modal.jsx
│   │   ├── ConfirmDialog.jsx
│   │   ├── Toast.jsx
│   │   └── DataList.jsx
│   │
│   └── domain/
│       ├── AppointmentCard.jsx
│       ├── ProfessionalHeader.jsx
│       ├── CapacityMeter.jsx
│       ├── SmartStrip.jsx
│       ├── AiInsightCard.jsx
│       ├── CashSummaryCard.jsx
│       └── InventoryAlertCard.jsx
│
└── modules/

Adapte os nomes à arquitetura existente quando necessário, mas preserve a separação de responsabilidades.

FASE 2 — TOKENS CANÔNICOS

Criar tokens semânticos.

PALETA

Verde-esmeralda:

--emerald-50: #ECFDF5;
--emerald-100: #D1FAE5;
--emerald-500: #10B981;
--emerald-600: #059669;
--emerald-700: #047857;
--emerald-900: #064E3B;

Azul-royal:

--royal-50: #EFF6FF;
--royal-100: #DBEAFE;
--royal-500: #2563EB;
--royal-600: #1D4ED8;
--royal-700: #1E40AF;
--royal-900: #172554;

Neutros:

--slate-0: #FFFFFF;
--slate-25: #FCFCFD;
--slate-50: #F8FAFC;
--slate-100: #F1F5F9;
--slate-200: #E2E8F0;
--slate-300: #CBD5E1;
--slate-500: #64748B;
--slate-700: #334155;
--slate-900: #0F172A;
--slate-950: #08111F;

Estados:

--success: #059669;
--warning: #D97706;
--danger: #DC2626;
--info: #2563EB;
--ai: #6D5CE7;

PAPÉIS SEMÂNTICOS

--color-action-primary;
--color-action-primary-hover;
--color-intelligence;
--color-success;
--color-warning;
--color-danger;
--color-info;
--color-text-primary;
--color-text-secondary;
--color-text-muted;
--color-border;
--color-border-strong;
--color-canvas;
--color-surface;
--color-surface-elevated;
--color-surface-muted;
--color-focus;

ESPAÇAMENTO

--space-1: 4px;
--space-2: 8px;
--space-3: 12px;
--space-4: 16px;
--space-5: 20px;
--space-6: 24px;
--space-8: 32px;
--space-10: 40px;
--space-12: 48px;

RADIUS

--radius-sm: 8px;
--radius-md: 12px;
--radius-lg: 16px;
--radius-xl: 22px;
--radius-pill: 999px;

CONTROLES

--control-sm: 36px;
--control-md: 44px;
--control-lg: 52px;

MOTION

--motion-fast: 120ms;
--motion-base: 180ms;
--motion-slow: 240ms;

TIPOGRAFIA

Usar system font stack:

system-ui,
-apple-system,
BlinkMacSystemFont,
"SF Pro Display",
"SF Pro Text",
"Segoe UI",
sans-serif;

Criar papéis tipográficos:

- display;
- page-title;
- section-title;
- card-title;
- body;
- supporting;
- metadata;
- label.

Não importar fonte externa pesada sem justificativa.

FASE 3 — APP SHELL RESPONSIVA

Criar uma única App Shell adaptativa.

DESKTOP — 1200 PX OU MAIS

Implementar:

- Sidebar fixa;
- Topbar contextual;
- conteúdo fluido;
- bottom action bar apenas quando uma operação exigir.

Sidebar:

- largura expandida entre 240 e 264 px;
- opção compacta entre 72 e 80 px;
- logo;
- rotas;
- ícones;
- estado ativo;
- organização;
- usuário;
- permissões;
- logout;
- sincronização, quando relevante.

Rotas principais:

- Início;
- Agenda;
- Comandas;
- Clientes;
- Equipe;
- Caixa;
- Estoque;
- Financeiro;
- Relatórios;
- Marketing;
- Configurações.

Não exibir itens sem permissão.

Topbar desktop:

- título da página;
- contexto ou data;
- seletor de unidade;
- busca;
- notificações;
- ajuda;
- avatar;
- ação principal contextual.

TABLET PAISAGEM

Usar:

- Navigation Rail;
- Topbar;
- conteúdo em múltiplos painéis quando útil.

Navigation Rail:

- 72 a 88 px;
- ícone e rótulo curto;
- mesma fonte de rotas da Sidebar;
- estado ativo claro;
- tooltip quando necessário.

TABLET RETRATO E MOBILE

Usar:

- Topbar;
- Bottom Navigation;
- conteúdo em uma coluna;
- Bottom Sheet para filtros e ações secundárias.

Bottom Navigation:

- Hoje;
- Agenda;
- Comanda;
- Clientes;
- Mais.

Não exibir mais de cinco itens.

O menu “Mais” contém:

- Equipe;
- Caixa;
- Estoque;
- Catálogo;
- Financeiro;
- Relatórios;
- Organização;
- Configurações.

SAFE AREA

Aplicar:

- env(safe-area-inset-top);
- env(safe-area-inset-bottom);
- proteção contra barras do sistema;
- proteção contra teclado virtual.

FASE 4 — HOME “HOJE” EM BENTO GRID

Criar a rota principal “Hoje”.

A Home deve ser uma superfície de síntese, não um dashboard decorativo.

GRID DESKTOP

Usar 12 colunas.

Composição sugerida:

Linha 1:
- Receita hoje: 3 colunas;
- Ocupação: 3 colunas;
- Agendamentos: 3 colunas;
- Encaixes possíveis: 3 colunas.

Linha 2:
- Agenda de hoje: 12 colunas.

Linha 3:
- Kortex IA: 4 colunas;
- Alertas: 4 colunas;
- Resumo financeiro: 4 colunas.

MOBILE

Ordenar por prioridade operacional:

1. próximo atendimento;
2. alerta crítico;
3. agenda de hoje;
4. ocupação;
5. encaixes;
6. caixa;
7. inteligência.

REGRAS

- Uma ação principal por card.
- Cards não devem competir visualmente.
- Verde-esmeralda para resultado e ação.
- Azul-royal para IA, links e dados informativos.
- Evitar gradientes fortes.
- Usar bordas suaves e sombras discretas.
- Cards devem funcionar em modo claro e futuro modo escuro.
- Conteúdo deve continuar legível sem cor.

FASE 5 — REIMPLEMENTAR A AGENDA

A Agenda é a principal superfície operacional.

ESTRUTURA MOBILE

1. Topbar.
2. Faixa semanal.
3. Profissionais.
4. Smart Strip.
5. Timeline.
6. Bottom Navigation.

TOPO

Topbar compacta entre 56 e 64 px.

Exibir:

- título Agenda;
- data atual;
- busca;
- filtros;
- ação para novo agendamento.

Não sobrecarregar a Topbar.

FAIXA SEMANAL

Exibir:

- dia da semana;
- número;
- estado selecionado;
- quantidade de agendamentos opcional.

Calendário mensal:

- fechado por padrão;
- aberto em Bottom Sheet ou expansão vertical;
- nunca ocupar mais de aproximadamente 30% da altura útil.

PROFISSIONAIS

Exibir:

- avatar;
- primeiro nome;
- quantidade de atendimentos;
- percentual ou indicador de ocupação;
- estado de disponibilidade.

Desktop:

- cabeçalhos de profissionais sobre colunas.

Mobile:

- seletor horizontal;
- permitir seleção de um profissional ou visão compacta múltipla;
- sticky quando houver rolagem.

SMART STRIP

Criar componente com altura aproximada entre 44 e 56 px.

Exibir uma informação por vez:

- profissional livre;
- atraso;
- conflito;
- encaixe;
- espera;
- aviso de caixa;
- insight da IA.

Características:

- recolhível;
- dispensável;
- não cobrir a agenda;
- não abrir modal automaticamente;
- não interromper fluxo;
- registrar ação quando usuário aceitar sugestão.

TIMELINE

Implementar:

- horas;
- divisões de 15, 20 ou 30 minutos conforme configuração;
- linha de horário atual;
- indicador “Agora”;
- scroll automático seguro;
- sticky time labels;
- sticky professional headers;
- áreas indisponíveis;
- espaços livres;
- conflitos;
- horários bloqueados.

CARDS DE AGENDAMENTO

Exibir:

- horário;
- cliente;
- serviço;
- profissional quando necessário;
- estado;
- ícones secundários relevantes.

Não preencher o card inteiro com cor saturada.

Usar:

- fundo neutro;
- barra lateral de 3 a 4 px;
- badge;
- texto;
- ícone.

ESTADOS

- confirmado: esmeralda;
- aguardando: âmbar;
- em atendimento: azul-royal;
- concluído: neutro com check;
- cancelado: cinza e texto reduzido;
- falta: vermelho;
- encaixe: roxo discreto;
- conflito: vermelho com ícone e mensagem.

Não usar cor como único indicador.

FAB OU AÇÃO PRIMÁRIA

No mobile:

- botão flutuante verde-esmeralda;
- ação: novo agendamento;
- respeitar a Bottom Navigation;
- respeitar safe area;
- desaparecer quando competir com modais ou checkout.

Desktop:

- ação na Topbar;
- FAB opcional apenas se comprovadamente útil.

FASE 6 — PRIMITIVES E PATTERNS

BUTTON

Variantes:

- primary;
- secondary;
- ghost;
- danger;
- link;
- icon-only.

Estados:

- default;
- hover;
- active;
- focus-visible;
- loading;
- disabled.

INPUT E SELECT

Implementar:

- label;
- helper text;
- erro;
- sucesso;
- prefixo;
- sufixo;
- ícone;
- disabled;
- loading;
- foco visível.

CARD

Variantes:

- default;
- elevated;
- interactive;
- selected;
- muted;
- intelligence;
- warning;
- danger.

MODAL

Desktop:

- central;
- largura adequada;
- focus trap;
- Escape;
- retorno de foco;
- bloqueio de scroll;
- aria-labelledby.

Mobile:

- Bottom Sheet;
- CTA fixo;
- teclado não pode esconder a ação;
- drag handle;
- altura adaptativa.

SKELETON

Substituir textos como:

- “Carregando agenda…”;
- “Carregando caixa…”;
- spinners estruturais.

Skeleton deve reservar o espaço final para evitar layout shift.

FASE 7 — ESTADOS OBRIGATÓRIOS

Cada módulo implementado deve possuir:

1. Loading.
2. Conteúdo.
3. Vazio.
4. Erro recuperável.
5. Erro irreversível.
6. Offline.
7. Sem permissão.
8. Sincronizando.
9. Dados potencialmente desatualizados.
10. Sucesso.
11. Undo, quando aplicável.

Não deixar telas vazias ou mensagens técnicas expostas ao usuário.

FASE 8 — ACESSIBILIDADE

Meta: WCAG 2.2 AA.

Implementar:

- HTML semântico;
- labels;
- aria somente quando necessário;
- navegação por teclado;
- foco visível;
- ordem correta de tabulação;
- focus trap;
- retorno de foco;
- contraste;
- alvos de toque entre 44 e 48 px;
- suporte a leitores de tela;
- mensagens de erro associadas aos campos;
- prefers-reduced-motion;
- cor nunca usada isoladamente;
- tooltips acessíveis;
- menus operáveis por teclado.

FASE 9 — PERFORMANCE

Metas:

- LCP ≤ 2,5 s;
- INP ≤ 200 ms;
- CLS ≤ 0,1.

Aplicar:

- lazy loading por módulo;
- code splitting;
- memoização apenas quando mensurada;
- mapas de entidades por ID;
- evitar múltiplos `.find()` durante renderizações;
- virtualização quando necessário;
- reserva de espaço;
- skeletons;
- imports de ícones seletivos;
- imagens otimizadas;
- evitar bibliotecas visuais excessivas;
- manter conteúdo anterior durante revalidação;
- optimistic UI em ações seguras.

AGENDA

Preparar para:

- grande número de profissionais;
- agenda extensa;
- múltiplos cards;
- scroll;
- filtros;
- atualização em tempo real.

Evitar renderizar toda a agenda quando apenas parte está visível, caso volume real justifique virtualização.

FASE 10 — PWA E OFFLINE

Preservar ou melhorar:

- manifest;
- Service Worker;
- ícones;
- instalação;
- cache;
- fallback offline;
- atualização;
- versionamento;
- sincronização.

Não armazenar dados financeiros ou operacionais críticos sem estratégia de atualização.

Exibir claramente:

- offline;
- sincronizando;
- sincronizado;
- falha de sincronização;
- dados desatualizados.

Não permitir que o usuário acredite que uma alteração foi salva quando não foi.

FASE 11 — TEMA ESCURO

Não fazer do tema escuro a prioridade da primeira onda.

Estruturar tokens para suportá-lo, mas concluir primeiro o modo claro.

O modo claro é o padrão operacional.

O modo escuro deve:

- preservar hierarquia;
- evitar preto puro em grandes superfícies;
- manter contraste;
- não depender de neon;
- não sacrificar legibilidade;
- não mudar papéis semânticos das cores.

FASE 12 — TESTES

Criar ou adaptar testes para:

- renderização da App Shell;
- permissões de navegação;
- Sidebar;
- Navigation Rail;
- Bottom Navigation;
- Topbar;
- Agenda;
- faixa semanal;
- Smart Strip;
- criação de agendamento;
- estados de erro;
- estados offline;
- Modal;
- Bottom Sheet;
- navegação por teclado.

RESPONSIVIDADE

Testar:

- 320 × 568;
- 360 × 800;
- 390 × 844;
- 430 × 932;
- 768 × 1024;
- 1024 × 768;
- 1180 × 820;
- 1366 × 768;
- 1440 × 900;
- 1920 × 1080.

Validar:

- overflow;
- clipping;
- safe areas;
- teclado virtual;
- barras fixas;
- agenda;
- modais;
- bottom sheets;
- rotação;
- scroll horizontal.

FASE 13 — IMPLEMENTAÇÃO INCREMENTAL

A ordem obrigatória é:

ONDA 0
- inventário;
- baseline;
- build;
- testes;
- riscos.

ONDA 1
- foundations;
- tokens;
- primitives.

ONDA 2
- App Shell;
- navegação responsiva.

ONDA 3
- Home Hoje;
- Agenda.

ONDA 4
- Comanda;
- Clientes;
- Caixa;
- Estoque;
- Equipe;
- Catálogo;
- Organização.

ONDA 5
- acessibilidade;
- performance;
- PWA;
- testes;
- dark mode.

Não começar a refatoração de todos os módulos simultaneamente.

FASE 14 — CRITÉRIOS DE ACEITE

A primeira entrega só estará concluída quando:

1. Desktop usar Sidebar + Topbar.
2. Tablet paisagem usar Navigation Rail + Topbar.
3. Tablet retrato usar Topbar + Bottom Navigation.
4. Mobile usar Topbar + Bottom Navigation.
5. Não existir navegação global duplicada.
6. A Home Hoje estiver implementada em Bento Grid funcional.
7. A Agenda ocupar aproximadamente 75% a 80% da altura útil.
8. O calendário mensal iniciar fechado.
9. Smart Strip existir e não interromper a operação.
10. Os principais componentes vierem da biblioteca canônica.
11. Estados de loading, erro, vazio e offline estiverem implementados.
12. Mobile funcionar com uma mão.
13. Não existir scroll horizontal indevido.
14. Foco, teclado e contraste passarem na auditoria.
15. Build, lint e testes passarem.
16. O relatório final listar pendências reais.
17. Nenhuma alteração quebrar autenticação, permissões ou multiempresa.

FORMATO DE TRABALHO

Antes de editar:

1. Apresente o plano.
2. Liste arquivos que serão alterados.
3. Liste riscos.
4. Identifique dependências.
5. Defina o primeiro checkpoint.

Durante a implementação:

- trabalhe em mudanças pequenas;
- execute build após cada onda;
- não acumule dezenas de alterações sem validação;
- preserve contratos existentes;
- documente decisões.

Ao terminar cada onda, entregue:

1. Arquivos alterados.
2. O que foi implementado.
3. O que foi preservado.
4. O que não foi implementado.
5. Testes executados.
6. Resultados.
7. Riscos restantes.
8. Próximo passo recomendado.

RELATÓRIO FINAL OBRIGATÓRIO

Entregar:

1. Resumo executivo.
2. Antes e depois da arquitetura.
3. Árvore de componentes.
4. Tokens criados.
5. Rotas e navegação.
6. Implementação da Home.
7. Implementação da Agenda.
8. Responsividade.
9. Acessibilidade.
10. Performance.
11. PWA.
12. Testes.
13. Débitos restantes.
14. Riscos.
15. Backlog P0–P3.
16. Screenshots por breakpoint.
17. Comandos executados.
18. Critérios de aceite aprovados e reprovados.

REGRA DE QUALIDADE

Não declare que a interface está “premium” com base em aparência subjetiva.

Comprove por:

- consistência;
- clareza;
- densidade;
- acessibilidade;
- responsividade;
- tempo de tarefa;
- estabilidade;
- feedback;
- ausência de duplicação;
- aderência ao Design System.

PRIMEIRA TAREFA

Comece somente com:

1. auditoria do front-end atual;
2. criação dos foundations;
3. criação dos primitives essenciais;
4. refatoração da App Shell;
5. implementação da Home Hoje;
6. implementação da Agenda como superfície-piloto.

Não avance para os demais módulos antes da validação desses seis itens.
```

## Prompt complementar para execução sem desvios

Use este bloco junto ao prompt principal:

```text
CONTROLE DE ESCOPO

Não transforme esta tarefa em uma reescrita geral.

Priorize:

1. Foundations.
2. App Shell.
3. Home Hoje.
4. Agenda.
5. Testes.

Não priorize agora:

- dark mode completo;
- novos módulos;
- microserviços;
- troca de framework;
- animações complexas;
- gráficos avançados;
- IA generativa real;
- redesign do backend;
- alterações de banco não necessárias.

Quando houver dúvida entre uma solução sofisticada e uma solução simples, estável e reversível, escolha a segunda.

Quando uma referência visual conflitar com o Kortex Design System v1.0, prevalece o Design System.

Quando estética conflitar com eficiência operacional, prevalece a eficiência operacional.

Quando desktop e mobile exigirem comportamentos diferentes, compartilhe lógica, dados, permissões e componentes, mas adapte composição e interação.

Não aceite como conclusão:

- apenas criar CSS;
- apenas criar componentes sem adoção;
- apenas criar mockups;
- apenas passar no build;
- apenas copiar a imagem de referência.

A entrega precisa funcionar no repositório real.
```
