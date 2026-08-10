# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Donos/gerentes de salões e barbearias de beleza e bem-estar no Brasil, e sua equipe operacional (recepção, profissionais) — usando esta PWA no dia a dia para rodar a operação: agenda, checkout/comanda, caixa, estoque, catálogo, equipe. O cliente final (quem agenda um horário) ainda não é o usuário primário desta PWA; terá canal próprio no futuro (AppCliente — identidade/dispositivo/inbox já existem na base de dados, mas a entrega real via push/FCM é backlog separado, sem infraestrutura hoje).

## Product Purpose

KortexOS™ é um sistema operacional de capacidade, dinheiro, confiança, recorrência, atendimento, execução e decisão para negócios de beleza e bem-estar. Existe para transformar tempo disponível (agenda) em receita protegida, previsível e auditável: menos buraco na agenda, mais ocupação em dias fracos, mais recorrência, caixa previsível, margem e comissão protegidas, menos dependência operacional do dono. Sucesso é medido nesses termos operacionais e financeiros, não em engajamento de app.

## Positioning

KortexOS™ não compete como "agenda online" — compete como infraestrutura operacional. O diferencial confirmado por benchmark contra os líderes do setor (Booksy, Boulevard, Vagaro, Trinks, AppBarber, CashBarber, Mindbody, Fresha):

- **Waitlist reativa em tempo real**, disparada por cancelamento — gap real que nem Boulevard nem Vagaro cobrem hoje.
- **Ledger de dinheiro com integridade double-entry**, sem edição retroativa de fechamento já apurado — ponto em que o Trinks diverge (anti-padrão documentado nesse mercado).
- **Comissão e assinatura nativas e rastreáveis** — lacuna que players especializados em recorrência (ex. CashBarber) não cobrem nativamente.
- **Execução auditável e gates de promoção como moat**, não feature solta: nada muda verdade de produção sem Blueprint aprovado e evidência reproduzida.

Existe uma tese de longo prazo de um "Autonomous Operations Engine" (decidir quem contatar, quando, por qual canal, com qual impacto econômico) registrada na documentação de visão do produto. Essa tese é direção de roadmap, não posicionamento atual: o que está confirmado e em construção validada hoje é a operação core acima — agenda, checkout, caixa, comissão, e a fundação de recorrência/waitlist/group booking (Onda 5, fechada localmente) mais a reabertura governada de comanda fechada (Onda 6, em desenho).

## Operating Context

Operação diária de um salão/barbearia brasileiro: agenda multi-profissional, checkout de comanda (venda, desconto, gorjeta, estorno), caixa (lançamento manual de entrada/saída, histórico de movimentação), estoque de produtos, catálogo de serviços/pacotes, equipe (níveis, comissão por serviço, convites, capacidades), e clientes. Multi-tenant por organização (`organization_id`), com unidade (`unit_id`, filial) como fronteira secundária obrigatória em todo fato transacional novo. Terminologia de domínio fica em pt-BR nas telas e em inglês no código/schema (comanda, caixa, gorjeta, estorno, lançamento, unidade/unit, organização/organization).

## Capabilities and Constraints

- Backend Express é dono das regras de negócio e valida o JWT do Supabase Auth; a PWA nunca recebe `service_role` e nunca escreve verdade financeira diretamente.
- Tenant deriva sempre de membership autenticada — nunca de body/query isolado.
- Toda tabela de negócio tem `organization_id`, RLS e FK tenant-safe.
- Dinheiro é sempre inteiro em centavos; checkout é atômico e idempotente (`Idempotency-Key`).
- Migrations são criadas via Supabase CLI e testadas em ambiente local/descartável antes de produção.
- A PWA é modular e offline-first, e deve usar exclusivamente os primitivos do Kortex Design System (`Button`, `Input`, `Select`, `Badge`, `Modal`, `ActionRequestModal` etc., em `ui/primitives`) — nunca tags HTML nativas fora deles.
- A tela principal (Agenda) usa obrigatoriamente layout em Timeline Vertical.
- Todo modal novo usa a casca compartilhada `<Modal size="sm"|"md"|"lg"|"xl">`, com rolagem interna (`max-height: 90vh`) e comportamento de Bottom-Sheet em telas móveis (< 640px).
- Novas capacidades de Onda usam `useFeatureFlag('flag_name')` para respeitar Dark Launching antes de ativação em produção.
- O MVP técnico (Fases 1–11, Trilhas A–E) foi encerrado formalmente em produção em 2026-07-20; a execução atual segue o Migration Map / Blueprint 5.1.2 por Ondas, cada uma com gates de ambiente (feature → staging → main) antes de alcançar produção.
- Em aberto / não construído ainda: runtime AppCliente (app do cliente final) e a infraestrutura externa de entrega de push (FCM) são backlog separado, sem cronograma fechado.

## Brand Commitments

"KortexOS™" é o nome comercial e operacional travado. "HOPE OS" é legado histórico interno e "SMART Flow™" é legado conceitual/arquitetural de uma fase anterior (4.0) — nenhum trabalho futuro deve tratá-los como produtos paralelos ao KortexOS™. Identidade visual, logo e tom de voz formal ainda não foram decididos; nenhuma referência visual está travada além do Kortex Design System já implementado em código (ver `frontend/src/ui/foundations/tokens.css` como fonte viva).

## Evidence on Hand

Documentação interna extensa e canônica, mantida como fonte de verdade do produto: Master Briefing (visão e tese), Truth Map e Migration Map (estado técnico real por Onda), Decision Log (DEC-01 em diante), ADRs, Global Benchmark Map e Comparative Proposal (pesquisa comparativa vs. Booksy, Boulevard, Vagaro, Trinks, AppBarber, CashBarber, Mindbody, Fresha), e Políticas de Negócio. Nenhum asset de marketing público, depoimento de cliente real, case study ou métrica de produção está disponível — trabalho futuro não deve fabricar nenhum desses.

## Product Principles

1. O backend é a única fonte de verdade financeira e de tenant; a PWA nunca decide nem escreve verdade crítica por conta própria.
2. Execução auditável e reversível (versionamento, ledger íntegro, sem edição retroativa) é o moat do produto, não uma feature isolada.
3. O diferencial vem de coordenar domínios já existentes (capacidade, dinheiro, confiança, recorrência) melhor que os líderes do setor — não de copiar feature por feature.
4. Nada é ativado em produção sem Blueprint aprovado, Truth Map atualizado e os gates de ambiente cumpridos.
5. Uma Onda nova nunca herda numeração ou escopo do MVP encerrado; cada Onda é desenhada, implementada e auditada por si.

## Accessibility & Inclusion

Contraste mínimo WCAG AAA para legendagem (mais rigoroso que o padrão AA), com fonte mínima de `0.75rem` — invariante explícito do projeto, não uma meta aspiracional.
