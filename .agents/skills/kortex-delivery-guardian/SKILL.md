---
name: kortex-delivery-guardian
description: Planeja, audita e protege segredos, integridade do repositório e deploy do KortexOS.
---

# Guardar dados, segredos e entrega

## 1. Quando ativar
- Em tarefas que envolvam alteração de `.gitignore`, `.env.example`, arquivos de configuração do GitHub Actions/CI, Blueprint da nuvem (Render/render.yaml) ou preparação de deploys.

## 2. Quando não ativar
- Durante desenvolvimento diário de regras de negócio, testes unitários ou escrita de código na UI que não afetem a infraestrutura.

## 3. Objetivo
- Garantir que o repositório esteja estruturado corretamente, livre de segredos expostos, e configurado para builds e deploys determinísticos e seguros.

## 4. Entradas necessárias
- Configurações atuais de ambiente (`.env.example`), arquivo `render.yaml`, e logs ou arquivos do pipeline de CI.

## 5. Fluxo mínimo
1. Carregar a estrutura canônica do repositório a partir de [references/repository-contract.md](references/repository-contract.md).
2. Auditar `.gitignore` e verificar chaves confidenciais expostas (ex: rodar secret scans).
3. Validar se segredos como `SUPABASE_SERVICE_ROLE_KEY` estão restritos ao servidor e isolados do frontend.
4. Validar o arquivo `render.yaml` e as etapas de build/start contra as convenções do projeto.
5. Inspecionar o andamento do pipeline CI de integração contínua.

## 6. Restrições críticas
- Nunca commitar chaves privadas, segredos reais ou arquivos `.env`.
- Impedir que arquivos `data/*.json` sejam usados como verdade operacional dinâmica em produção.
- Proibir ações automáticas de Git push, commits diretos em branch principal, ou aplicação de Blueprints sem aprovação explícita.
- Não provisionar banco de dados redundante na nuvem de deploy (ex: Postgres no Render) uma vez que a persistência oficial é o Supabase.

## 7. Arquivos que podem ser carregados
- [references/repository-contract.md](file:///c:/Users/hudso/OneDrive/Documentos/Kortex%20Os%20v2/.agents/skills/kortex-delivery-guardian/references/repository-contract.md)

## 8. Condição de parada
- Repositório auditado, sem chaves expostas, arquivo `render.yaml` validado e build/deploy configurados corretamente.

## 9. Formato de saída
- Relatório de auditoria de entrega:
```text
CONFIG_AUDIT:
- Secret Scan: <CLEAN/FAILED>
- Gitignore Validated: <SIM/NÃO>
- Render Blueprint Validated: <SIM/NÃO>
DELIVERY_STATUS:
- CI Status: <PASS/FAIL>
- Deploy Readiness: <READY/BLOCKED>
```
