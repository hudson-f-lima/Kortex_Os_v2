import { useOrganization } from '../shared/useOrganization.js';
import { modulesForRole } from '../shared/nav.js';

// Estado "sem permissão" explícito quando o papel do usuário na organização
// atual não inclui este módulo (ex.: professional acessando /caixa direto
// pela URL) — nunca um crash genérico.
export function RoleGatedRoute({ slug, children }) {
  const { role } = useOrganization();
  const allowed = modulesForRole(role).some((module) => module.slug === slug);

  if (!allowed) {
    return (
      <div className="module-placeholder">
        <h1>Sem permissão</h1>
        <p>Seu papel nesta organização não tem acesso a este módulo.</p>
      </div>
    );
  }

  return children;
}
