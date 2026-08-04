# Contratos do MAS

## Envelope de tarefa

Toda delegação deve conter: objetivo, arquivos permitidos, arquivos proibidos, autoridade (`read-only`, `draft`, `edit`), entradas canônicas, formato de saída, testes e condição de parada.

## Envelope de resposta

Todo especialista deve retornar: achados classificados, evidências com caminhos, decisões, riscos, arquivos alterados, testes executados e bloqueios.

## Ondas e gates

1. **Descoberta:** Truth Mapper e especialistas de domínio produzem fatos sem editar.
2. **Desenho:** `$kortex-blueprint-architect` propõe o contrato técnico, fechando toda decisão aberta via `$grill-me` antes de redigir.
3. **Fatiamento:** o Blueprint aprovado é quebrado em fatias verticais pequenas via `$prd-to-issues` (formato `issues/NNN-titulo.md`, tracer bullet — schema→API→teste de ponta a ponta, nunca uma camada isolada). Cada fatia é marcada `HITL` (exige decisão do Platform Owner) ou `AFK` (implementável sem parar). Nenhuma migration de Onda inteira em um único commit — é assim que uma lacuna de segurança passa despercebida até auditoria (ver incidente Onda 0, 2026-07-24: RLS org-wide e FK `RESTRICT` só foram achados depois da declaração de "concluído").
4. **Implementação:** cada fatia usa `$tdd` — um teste por comportamento, RED→GREEN, nunca "escrever todos os testes primeiro, depois todo o código" (slicing horizontal produz teste que não pega regressão real).
5. **Validação:** QA e Red Team tentam quebrar tenant, dinheiro, estoque, agenda, cache e entrega — por fatia relevante, não só no fim da Onda inteira. Todo achado de `$kortex-qa-redteam` deve vir acompanhado de evidência bruta (saída de comando, log, resultado de teste) executada diretamente por quem relata — nunca aceito como relato resumido de um subagente delegado sem reverificação direta. Um `CRÍTICO` sem mitigação implica `NO-GO`.
6. **Integração:** somente o orquestrador consolida mudanças conflitantes entre fatias.

Para a transição MVP → produto final KortexOS 5.1.2 (`docs/KORTEXOS_5_1_2_TRUTH_MAP.md`), a onda de Descoberta usa `$kortex-truth-mapper`; a onda seguinte, ainda de mapeamento (não de Desenho), usa `$kortex-migration-mapper` — só ativa depois do Truth Map vigente aprovado e registrado como DEC. Desenho de domínio novo (Blueprint) permanece bloqueado até o Migration Map existir.

Avançar de onda somente com entradas citadas, escopo preservado e bloqueios registrados.

## Registro automático de decisão

Toda aprovação formal do Platform Owner (Blueprint, autorização de SQL/Etapa 8, promoção de ambiente) gera o registro do DEC correspondente no Decision Log — e o ADR correspondente via `$documentation-and-adrs` quando a decisão é arquitetural/técnica, não de processo — como parte do mesmo fluxo que obteve a aprovação. Isso nunca é uma tarefa separada que aguarda o Platform Owner lembrar de pedir; é passo obrigatório de saída de qualquer skill que obtenha aprovação explícita.

## Limites de autoridade

Planejar não autoriza implementar. Draft não autoriza executar. Credencial disponível não autoriza deploy. A aprovação do agente não substitui a do Platform Owner. Fatiar em `AFK` não dispensa Red Team nem registro de decisão — só dispensa parar para uma decisão de negócio no meio da fatia.
