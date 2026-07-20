# Contratos do MAS

## Envelope de tarefa

Toda delegação deve conter: objetivo, arquivos permitidos, arquivos proibidos, autoridade (`read-only`, `draft`, `edit`), entradas canônicas, formato de saída, testes e condição de parada.

## Envelope de resposta

Todo especialista deve retornar: achados classificados, evidências com caminhos, decisões, riscos, arquivos alterados, testes executados e bloqueios.

## Ondas e gates

1. **Descoberta:** Truth Mapper e especialistas de domínio produzem fatos sem editar.
2. **Desenho:** arquitetos propõem contratos compatíveis com os fatos.
3. **Validação:** QA e Red Team tentam quebrar tenant, dinheiro, estoque, agenda, cache e entrega.
4. **Integração:** somente o orquestrador consolida mudanças conflitantes.

Para a transição MVP → produto final KortexOS 5.1.2 (`docs/KORTEXOS_5_1_2_TRUTH_MAP.md`), a onda de Descoberta usa `$kortex-truth-mapper`; a onda seguinte, ainda de mapeamento (não de Desenho), usa `$kortex-migration-mapper` — só ativa depois do Truth Map vigente aprovado e registrado como DEC. Desenho de domínio novo (Blueprint) permanece bloqueado até o Migration Map existir.

Avançar de onda somente com entradas citadas, escopo preservado e bloqueios registrados. Um `CRÍTICO` sem mitigação implica `NO-GO`.

## Limites de autoridade

Planejar não autoriza implementar. Draft não autoriza executar. Credencial disponível não autoriza deploy. A aprovação do agente não substitui a do Platform Owner.
