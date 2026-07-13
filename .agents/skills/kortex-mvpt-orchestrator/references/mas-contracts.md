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

Avançar de onda somente com entradas citadas, escopo preservado e bloqueios registrados. Um `CRÍTICO` sem mitigação implica `NO-GO`.

## Limites de autoridade

Planejar não autoriza implementar. Draft não autoriza executar. Credencial disponível não autoriza deploy. A aprovação do agente não substitui a do Platform Owner.
