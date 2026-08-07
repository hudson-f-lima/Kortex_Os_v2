# Contrato do repositório MVPT

```text
backend/
  src/{config,middleware,routes,services,engines,repositories,validators}/
  tests/
  package.json
frontend/
  src/{app,modules,shared}/
  public/{manifest.json,service-worker.js,icons/}
  package.json
supabase/migrations/
data/
  schemas/
  fixtures/
docs/{architecture,adr,operations}/
.env.example
.gitignore
render.yaml
package.json
```

`data/fixtures` deve conter somente dados sintéticos, IDs estáveis, versão de schema e nenhuma PII real. Dados privados e exports ficam ignorados e fora do histórico. Import/export operacional deve passar pelo backend e possuir validação, autorização e auditoria.

Variáveis mínimas: `NODE_ENV`, `PORT`, `SUPABASE_URL`, chave publicável para validar sessões, `SUPABASE_SERVICE_ROLE_KEY` server-only, `CORS_ORIGINS`, `LOG_LEVEL` e URL pública da API. O frontend recebe apenas URL e chave publicável.

Manter um único frontend ativo e um único service worker versionado. Diretórios de protótipo/legado não podem ser candidatos ambíguos ao build.
