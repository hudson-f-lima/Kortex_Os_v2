---
title: ADR 0021 — Design System Frontend, Modais Adaptativos, WCAG AAA e Governança de IA
status: APPROVED
stage: EXECUTED
governance_ref: DEC-44, DEC-45
upstream_doc: docs/architecture/vision/KORTEXOS_5_1_2_MASTER_BRIEFING_VISAO_TESE.md
last_updated: 2026-07-27
---

# ADR 0021: Design System Frontend, Modais Adaptativos, WCAG AAA e Governança de IA

## Contexto
Durante as auditorias de interface e usabilidade do frontend PWA (`kortex-pwa`), identificaram-se gargalos críticos de responsividade:
1. Modais travados com largura fixa (`max-width: 420px`), espremendo formulários complexos no PC e estourando a tela em celulares pequenos (360px).
2. Ausência de limite de altura (`max-height`) nos modais, empurrando os botões de ação ("Salvar" / "Cancelar") para fora da área visível sem rolagem interna.
3. Rótulos e textos secundários com contraste de cor insuficiente (`--muted: #6b6b6b`) e fonte minúscula (`0.65rem`), reprovando no padrão accessibility WCAG 2.1 AAA.
4. Ausência de suporte no PWA para controle de Feature Flags ativas no backend (`organizations.settings`) e para o modal de aprovação humana de ações da IA (`Action Request`, Master §6.3).

## Decisão Técnica

### 1. Sistema de Modais Adaptativos (`Modal.jsx` & `styles.css`)
- **Tamanhos Padronizados:** O componente casca [`Modal.jsx`](file:///c:/Users/hudso/OneDrive/Documentos/Kortex%20Os%20v2/frontend/src/shared/Modal.jsx) aceita a prop `size` com 4 tamanhos: `'sm'` (400px), `'md'` (540px), `'lg'` (720px) e `'xl'` (900px).
- **Rolagem Interna Protegida:** Todos os modais possuem `max-height: 90vh` com rolagem vertical interna (`overflow-y: auto`), garantindo que o cabeçalho e as ações inferiores permaneçam sempre visíveis.
- **Bottom-Sheet em Dispositivos Móveis:** Em viewports `< 640px`, todo modal é automaticamente renderizado como uma **Bottom-Sheet** ancorada na parte inferior do smartphone com bordas superiores arredondadas e animação `slideUp`.

### 2. Acessibilidade WCAG AAA & Tipografia Legível
- A variável de cor `--muted` foi ajustada para `#4a4a4a` no Light Mode e `#a3a3a3` no Dark Mode.
- O tamanho mínimo de fonte legível no sistema foi elevado de `0.65rem` para `0.75rem` (12px).
- Inclusão de suporte nativo a `env(safe-area-inset-bottom)` nas barras fixas inferiores para respeitar o notch e a navegação do iOS/Android.

### 3. Feature Flags & Componente de Governança de IA
- **React Hook `useFeatureFlag(flagName)`:** Exportado em [`useOrganization.js`](file:///c:/Users/hudso/OneDrive/Documentos/Kortex%20Os%20v2/frontend/src/shared/useOrganization.js), lendo dinamicamente as flags de Dark Launching configuradas na organização (DEC-44).
- **Primitiva `ActionRequestModal.jsx`:** Criado em [`src/ui/primitives/ActionRequestModal.jsx`](file:///c:/Users/hudso/OneDrive/Documentos/Kortex%20Os%20v2/frontend/src/ui/primitives/ActionRequestModal.jsx) para exibir sugestões sensíveis geradas pela IA (anulação de no-show, desconto fora de margem, fiado) com dados de impacto em centavos inteiros e aprovação/rejeição humana em 1 clique (Master §6.3).

## Consequências & Validação
- **Suíte de Testes Vitest:** **108/108 PASS (100% verde em 19 arquivos de teste)**.
- **Invariante Design System:** Mantida 100% a proibição de tags HTML nativas sem primitivas.
