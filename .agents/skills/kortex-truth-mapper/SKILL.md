---
name: kortex-truth-mapper
description: Auditar a verdade operacional do KortexOS comparando documentos canônicos, legado, código, testes, migrations e estado de deploy. Usar ao planejar módulos, resolver contradições, validar alegações de prontidão ou produzir um mapa de maturidade baseado em evidências.
---

# Mapear a verdade do KortexOS

1. Ler primeiro as instruções do repositório e sua fonte declarada de estado.
2. Ordenar autoridade: evidência executada; código e schema físicos; estado canônico atual; arquitetura aprovada; planejamento; legado.
3. Separar alegação, artefato e prova. Um documento de design não torna uma feature `REAL`.
4. Classificar cada achado com uma única classificação primária e, quando necessário, uma secundária.
5. Citar caminho, símbolo, teste, migration ou log que sustenta o achado.
6. Marcar divergências de nomes, versões, migrations e ownership como `CONTRADITÓRIO` ou `OBSOLETO`.
7. Produzir matriz: capacidade, estado, evidência, lacuna, risco, dependência e próximo gate.

Ler [references/classification.md](references/classification.md) antes de emitir o mapa final.

Não editar código durante uma auditoria de verdade. Não promover uma classificação por inferência otimista.
