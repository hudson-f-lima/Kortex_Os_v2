---
name: kortex-delivery-guardian
description: Planejar e auditar a entrega do KortexOS envolvendo data/*.json, contratos de configuração, .env/.env.example, .gitignore, varredura de segredos, Git/GitHub, CI e Render Blueprint. Usar para estruturar repositório, preparar deploy ou revisar riscos operacionais sem publicar nem usar credenciais sem autorização.
---

# Guardar dados, segredos e entrega

## Estruturar o repositório

Aplicar [references/repository-contract.md](references/repository-contract.md). Manter fixtures versionáveis separadas de dados reais; validar todo JSON por schema e impedir que `data/*.json` seja fonte de verdade em produção.

## Proteger configuração

- Versionar `.env.example` apenas com nomes, comentários e valores não secretos.
- Ignorar `.env`, variantes locais, logs, dumps, chaves privadas, node_modules, coverage e artefatos.
- Validar variáveis no boot e distinguir frontend público de backend secreto.
- Nunca colocar `SUPABASE_SERVICE_ROLE_KEY` em prefixo público, bundle ou static site.

## Entregar

Para o MVP com API e PWA separadas, preferir Blueprint versionado: web service Node/Express e static site PWA. Configurar health check, build/start, `PORT`, CORS explícito e secrets com `sync: false`. Publicar somente `dist/` allowlisted, nunca a raiz inteira. Usar `npm ci`, pin de Node e o lockfile do package root correto. Não provisionar Postgres Render quando Supabase é o banco.

No GitHub, exigir lockfiles, branch curta, PR, revisão e CI com testes, lint, auditoria de segredos e validação de artefatos. Verificar segredos/PII no histórico alcançável, não apenas no índice atual; qualquer reescrita de histórico ou rotação requer autorização do Owner. Não commitar, pushar, abrir PR ou aplicar Blueprint sem pedido explícito.

Verificar deploy somente após o repositório estar remoto e os segredos serem configurados. Reportar URL, status, health, logs e rollback.
