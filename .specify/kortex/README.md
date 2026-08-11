# KortexOS Spec Kit adapter

Esta pasta é a integração local e controlada do Spec Kit. Ela não é uma constituição paralela e não substitui `AGENTS.md`, o MAS, Truth Map, Migration Map, Blueprints, ADRs, DECs ou Guardians.

## Operação segura

1. Execute o pre-flight antes de iniciar um run.
2. Use `specify-cli 0.12.11`; não instale nem atualize automaticamente.
3. Mantenha o workflow em `read-only`/`dry-run` até que o gate correspondente esteja registrado.
4. Use somente o approval adapter allowlisted; `verdict_input` não é um controle de segurança confiável no pin atual.
5. Não coloque segredos, PII, tokens ou conteúdo bruto nos artefatos.

O protocolo de sincronização local continua obrigatório: antes de avaliar estado de gates, rode `git fetch` e compare a branch local com `origin/<branch>`.

## Rollback

Pare novos runs, preserve a telemetria e remova somente `.specify/kortex/` e os artefatos explicitamente criados por esta integração. Não use `git reset --hard`, `git checkout --` ou `specify init --force`.
