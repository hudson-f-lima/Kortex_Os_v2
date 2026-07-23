---
name: kortex-environment-guardian
description: Governa branches, promoção entre ambientes (local/staging/produção) e o mapeamento de qual Supabase/Render cada trabalho usa no KortexOS.
---

# Guardar ambientes e promoção

## 1. Quando ativar
- Antes de abrir ou aprovar qualquer Pull Request com destino `main` ou `staging`.
- Ao criar ou alterar workflows de CI/CD, `render.yaml`, ou qualquer configuração que aponte para um projeto Supabase específico.
- Ao decidir para qual ambiente (local, staging, produção) uma mudança deve apontar.

## 2. Quando não ativar
- Durante desenvolvimento local puro, sem intenção de abrir PR ou fazer deploy.

## 3. Objetivo
- Garantir que nenhuma mudança alcance produção sem antes ter soado em homologação, e que branch, ambiente e projeto Supabase usados em cada momento estejam corretos e nunca cruzados entre si.

## 4. Entradas necessárias
- Branch de origem e branch de destino da mudança.
- Estado atual de `staging` (validado manualmente ou não).
- `render.yaml` e a lista de projetos Supabase existentes (produção e staging).

## 5. Fluxo mínimo
1. Confirmar a branch de destino: toda branch de feature/fix nasce de `staging` e volta para `staging` via PR — nunca direto para `main`.
2. Recusar (bloquear) qualquer PR que tente ir de uma branch de feature direto para `main`.
3. Para um PR `staging` → `main`: confirmar explicitamente que a mudança já foi validada manualmente no ambiente de homologação (Render staging + Supabase staging) antes de aprovar.
4. Verificar que nenhum valor (URL, chave, `service_role`) do projeto Supabase de staging vazou para `render.yaml`/workflows de produção, e vice-versa.
5. Encaminhar o gate final de higiene de deploy ao `kortex-delivery-guardian` antes de qualquer merge em `main`.

## 6. Restrições críticas
- Nunca aprovar merge direto de uma branch de feature em `main` — sempre passar por `staging` primeiro.
- Nunca usar o projeto Supabase de produção para testes ou dados de homologação, nem o inverso.
- Nunca commitar segredos de nenhum ambiente (local, staging, produção) em `render.yaml` ou em arquivos de workflow.
- Não criar, pausar ou deletar projetos Supabase, nem serviços Render, sem aprovação explícita do Platform Owner (envolve custo e quota de conta).
- Não alterar proteção de branch (`main`/`staging`) sem aprovação explícita do Platform Owner.

## 7. Arquivos que podem ser carregados
- [render.yaml](file:///c:/Users/hudso/OneDrive/Documentos/Kortex%20Os%20v2/render.yaml)
- `.github/workflows/*.yml`
- [docs/KORTEXOS_5_1_2_DECISION_LOG.md](file:///c:/Users/hudso/OneDrive/Documentos/Kortex%20Os%20v2/docs/KORTEXOS_5_1_2_DECISION_LOG.md)

## 8. Condição de parada
- Branch de origem/destino corretos confirmados; se o destino é `main`, homologação validada antes; nenhum vazamento de segredo/ambiente encontrado; `kortex-delivery-guardian` acionado para o gate final antes do merge em `main`.

## 9. Formato de saída
```text
ENVIRONMENT_AUDIT:
- Branch origem/destino: <...>
- Staging validado (se destino = main): <SIM/NÃO/N-A>
- Projeto Supabase/Render corretos, sem cruzamento: <SIM/NÃO>
PROMOTION_STATUS:
- <READY FOR MAIN / READY FOR STAGING / BLOQUEADO, motivo>
```
