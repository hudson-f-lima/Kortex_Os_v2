---
name: kortex-qa-redteam
description: Definir gates e executar revisão adversarial do KortexOS em backend, Supabase, PWA e entrega. Usar antes de declarar um incremento pronto, seguro ou implantável, cobrindo tenant bypass, privilégios, idempotência, concorrência, dinheiro, estoque, agenda, cache, segredos e supply chain.
---

# Validar e atacar o incremento

1. Ler o escopo, invariantes, diff e evidências sem assumir que o plano foi implementado corretamente.
2. Montar matriz risco-controle-teste-evidência usando [references/gate-matrix.md](references/gate-matrix.md).
3. Executar testes existentes antes de adicionar cenários; registrar comando, resultado e ambiente.
4. Atacar caminhos negativos: outro tenant, sem auth, role errada, replay diferente, corrida, valor negativo, referência cruzada, offline, cache antigo, segredo ausente e deploy parcial.
5. Separar defeito observado de hipótese. Classificar severidade e maturidade.
6. Exigir regressão automatizada para correções críticas.
7. Emitir `NO-GO` para segredo exposto, bypass de tenant, corrupção financeira/estoque, mutação crítica não idempotente ou migration não autorizada.

Não corrigir silenciosamente durante Red Team. Entregar achados reproduzíveis ao agente responsável e revalidar depois da correção.
