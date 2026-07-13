---
name: kortex-pwa-architect
description: Planejar e revisar a PWA modular e rápida do KortexOS, incluindo app shell, módulos por domínio/persona, cliente HTTP, estado, manifest, service worker, cache, atualização, offline e segurança. Usar para frontend do ERP vertical e para impedir que UI, localStorage ou cache se tornem fonte de verdade crítica.
---

# Arquitetar a PWA modular

1. Dividir por capacidades: clientes, equipe, catálogo, agenda, estoque, checkout, caixa e relatórios essenciais.
2. Manter um app shell pequeno, carregar módulos sob demanda e compartilhar apenas componentes, cliente API e primitives de estado.
3. Tratar o backend como única fonte de verdade; a PWA solicita comandos e renderiza resultados.
4. Não calcular nem persistir como verdade preço, comissão, saldo, estoque, disponibilidade ou fechamento.
5. Aplicar política de cache por classe de recurso, conforme [references/cache-policy.md](references/cache-policy.md).
6. Projetar estados explícitos: loading, vazio, erro recuperável, offline, conflito, sem permissão e atualização disponível.
7. Invalidar cache após deploy e oferecer reload controlado; não deixar assets antigos quebrarem contratos novos.
8. Medir orçamento: bundle inicial, LCP, INP, payload de API e taxa de acerto de cache estático.
9. Testar instalação, atualização, reconexão, deep links e navegação por teclado.

Não guardar `service_role`, segredo de backend ou PII sensível no bundle, Cache Storage, IndexedDB ou logs.
