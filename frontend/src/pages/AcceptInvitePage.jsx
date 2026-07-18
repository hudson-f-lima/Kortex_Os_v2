import { useState } from 'react';
import { supabase } from '../shared/supabaseClient.js';

// Chegada aqui: clique no link de convite (auth.admin.inviteUserByEmail,
// backend/src/modules/convites). O redirectTo aponta para a RAIZ do site
// (SITE_URL), não para uma rota aninhada como /aceitar-convite — GitHub
// Pages não faz rewrite server-side de SPA, então uma rota aninhada 404 em
// acesso direto (ADR 0014, "Blind Spot"). A raiz é sempre servida como
// index.html, e o fragmento #access_token=...&type=invite chega intacto
// (fragmentos nunca são enviados ao servidor). main.jsx detecta
// `type=invite` no hash antes do AuthClient consumi-lo e renderiza esta tela
// no lugar do roteador normal; supabase.auth.getSession() aguarda a mesma
// promise interna que o AuthClient usa para processar esse hash
// (detectSessionInUrl: true), então a sessão do convite já está disponível
// quando o usuário submete a senha.
export function AcceptInvitePage() {
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState(null);
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);

  async function handleSubmit(event) {
    event.preventDefault();
    setError(null);

    if (password.length < 8) {
      setError('A senha deve ter pelo menos 8 caracteres.');
      return;
    }
    if (password !== confirmPassword) {
      setError('As senhas não coincidem.');
      return;
    }

    setSubmitting(true);
    const { data: sessionData } = await supabase.auth.getSession();
    if (!sessionData.session) {
      setSubmitting(false);
      setError('Link de convite inválido ou expirado. Peça um novo convite.');
      return;
    }

    const { error: updateError } = await supabase.auth.updateUser({ password });
    setSubmitting(false);
    if (updateError) {
      setError(updateError.message);
      return;
    }
    setDone(true);
    window.setTimeout(() => {
      window.location.href = import.meta.env.BASE_URL;
    }, 1200);
  }

  if (done) {
    return (
      <div className="auth-screen">
        <div className="auth-form">
          <h1>Tudo pronto</h1>
          <p>Sua senha foi definida. Entrando no KortexOS…</p>
        </div>
      </div>
    );
  }

  return (
    <div className="auth-screen">
      <form className="auth-form" onSubmit={handleSubmit}>
        <h1>Bem-vindo(a) ao KortexOS</h1>
        <p className="section-hint">Defina uma senha para concluir seu acesso.</p>
        <label>
          Senha
          <input
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            required
            minLength={8}
            autoComplete="new-password"
          />
        </label>
        <label>
          Confirmar senha
          <input
            type="password"
            value={confirmPassword}
            onChange={(event) => setConfirmPassword(event.target.value)}
            required
            minLength={8}
            autoComplete="new-password"
          />
        </label>
        {error && <p className="form-error" role="alert">{error}</p>}
        <button type="submit" disabled={submitting}>
          {submitting ? 'Salvando…' : 'Definir senha e entrar'}
        </button>
      </form>
    </div>
  );
}
