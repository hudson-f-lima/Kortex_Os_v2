import { useState } from 'react';
import { Modal } from '../../shared/Modal.jsx';
import { messageForError, FORBIDDEN_MESSAGE } from '../../shared/apiErrorMessage.js';
import { Button } from '../../ui/primitives/Button.jsx';
import { Input } from '../../ui/primitives/Input.jsx';

// Cria/edita clientes (docs/PWA_PLANEJAMENTO.md §4.1/§6): só os campos que o
// backend expõe (name/phone/email/active) — sem preferências/observações,
// que não existem no schema de clients.
export function ClientModal({ mode, client, apiClient, onClose, onSaved }) {
  const [name, setName] = useState(client?.name ?? '');
  const [phone, setPhone] = useState(client?.phone ?? '');
  const [email, setEmail] = useState(client?.email ?? '');
  const [active, setActive] = useState(client?.active ?? true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  async function handleSubmit(event) {
    event.preventDefault();
    if (!name.trim()) {
      setError('Informe o nome do cliente.');
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      const payload = {
        name: name.trim(),
        phone: phone.trim() || null,
        email: email.trim() || null,
        ...(mode === 'edit' ? { active } : {}),
      };
      const { client: saved } =
        mode === 'edit'
          ? await apiClient.patch(`/clients/${client.id}`, payload)
          : await apiClient.post('/clients', payload);
      onSaved(saved);
    } catch (err) {
      setError(messageForError(err, { statuses: { 403: FORBIDDEN_MESSAGE } }));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Modal onClose={onClose}>
      <h2>{mode === 'edit' ? 'Editar cliente' : 'Novo cliente'}</h2>
        <form className="auth-form" onSubmit={handleSubmit}>
          <Input 
            label="Nome" 
            value={name} 
            onChange={(event) => setName(event.target.value)} 
            required 
          />
          <Input 
            label="Telefone" 
            value={phone} 
            onChange={(event) => setPhone(event.target.value)} 
          />
          <Input 
            label="E-mail" 
            type="email" 
            value={email} 
            onChange={(event) => setEmail(event.target.value)} 
          />

          {mode === 'edit' && (
            <label className="inline-checkbox">
              <input type="checkbox" checked={active} onChange={(event) => setActive(event.target.checked)} />
              Ativo
            </label>
          )}

          {error && <p className="form-error" role="alert">{error}</p>}

          <div className="modal-actions">
            <Button variant="secondary" onClick={onClose}>
              Fechar
            </Button>
            <Button type="submit" disabled={submitting}>
              {mode === 'edit' ? 'Salvar' : 'Criar cliente'}
            </Button>
          </div>
        </form>
    </Modal>
  );
}
