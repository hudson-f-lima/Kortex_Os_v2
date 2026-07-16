---
name: kortex-mvpt-orchestrator
description: Orquestra agentes especialistas para planejar, fatiar e revisar o KortexOS MVP.
---

# Orquestrar o MVPT KortexOS

## 1. Quando ativar
- Solicitações de planejamento de macro-tarefas, fatiamento de funcionalidades do MVP ou coordenação de múltiplos agentes especialistas.

## 2. Quando não ativar
- Tarefas focadas em um único domínio específico (ex: escrever queries SQL, criar rotas Express, ajustar UI).

## 3. Objetivo
- Fatiar metas em incrementos curtos e seguros, coordenando especialistas e garantindo integridade arquitetural sem expandir escopo.

## 4. Entradas necessárias
- [AGENTS.md](file:///c:/Users/hudso/OneDrive/Documentos/Kortex%20Os%20v2/AGENTS.md) (regras e invariantes)
- [PROJECT_STATE.md](file:///c:/Users/hudso/OneDrive/Documentos/Kortex%20Os%20v2/docs/PROJECT_STATE.md) (estado operacional real)
- Definição do incremento solicitado pelo usuário.

## 5. Fluxo mínimo
1. Carregar e verificar `PROJECT_STATE.md` para basear decisões na realidade física do código.
2. Definir responsabilidades e delegar tarefas com escopo exclusivo para especialistas.
3. Coordenar em ondas: Descoberta, Desenho, Validação (QA/Red Team), e Integração final.
4. Consolidar os planos de implementação, logs de tarefas e relatórios de walkthrough.

## 6. Restrições críticas
- Proibir edição simultânea do mesmo arquivo por múltiplos agentes.
- Garantir que o tenant seja derivado de membership autenticada, rejeitando parâmetros isolados.
- Impedir exposição de chaves privilegiadas (`service_role`) e cálculos financeiros no frontend.
- Validar migrations novas localmente via Supabase CLI antes do deploy.

## 7. Arquivos que podem ser carregados
- [docs/INDEX.md](file:///c:/Users/hudso/OneDrive/Documentos/Kortex%20Os%20v2/docs/INDEX.md)
- [references/mas-contracts.md](file:///c:/Users/hudso/OneDrive/Documentos/Kortex%20Os%20v2/.agents/skills/kortex-mvpt-orchestrator/references/mas-contracts.md)

## 8. Condição de parada
- Incremento fatiado, planejado, validado por QA/Red Team e aprovado pelo usuário.

## 9. Formato de saída
```text
FILES_CHANGED:
- <caminho: natureza da mudança>
BLOCKERS_REMAINING:
- <pendências ou "nenhum">
VEREDITO:
- <classificação, decisão e próximo passo único>
```
