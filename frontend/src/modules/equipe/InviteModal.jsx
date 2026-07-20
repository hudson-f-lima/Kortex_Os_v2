import { useState } from 'react';
import { Modal } from '../../shared/Modal.jsx';
import { messageForError, FORBIDDEN_MESSAGE } from '../../shared/apiErrorMessage.js';
import { Button } from '../../ui/primitives/Button.jsx';
import { Input } from '../../ui/primitives/Input.jsx';
import { Select } from '../../ui/primitives/Select.jsx';

// POST /convites só aceita owner como ator (convites.route.js INVITE_ROLES,
// espelha membership_set) — convidar um 'owner' fica fora deste fluxo
// (ADR 0014), por isso a lista aqui já não inclui 'owner'.
const INVITE_ROLES = ['admin', 'manager', 'reception', 'professional'];

export function InviteModal({ apiClient, unlinkedProfessionals, onClose, onInvited }) {
  const [email, setEmail] = useState('');
  const [role, setRole] = useState('reception');
  const [professionalMode, setProfessionalMode] = useState('new');
  const [professionalName, setProfessionalName] = useState('');
  const [professionalId, setProfessionalId] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  async function handleSubmit(event) {
    event.preventDefault();
    setError(null);

    const payload = { email: email.trim(), role };
    if (role === 'professional') {
      if (professionalMode === 'existing') {
        if (!professionalId) {
          setError('Selecione um profissional já cadastrado para vincular.');
          return;
        }
        payload.professionalId = professionalId;
      } else if (professionalName.trim()) {
        payload.professionalName = professionalName.trim();
      }
    }

    setSubmitting(true);
    try {
      const { invite } = await apiClient.post('/convites', payload);
      onInvited(invite);
    } catch (err) {
      setError(
        messageForError(err, {
          fallback: 'Erro inesperado ao enviar convite.',
          statuses: { 403: FORBIDDEN_MESSAGE },
          codes: {
            email_already_invited: 'Este e-mail já foi convidado ou já tem uma conta.',
            professional_already_linked: 'Este profissional já está vinculado a outro usuário.',
          },
        }),
      );
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Modal onClose={onClose}>
      <h2>Convidar membro</h2>
      <form className="auth-form" onSubmit={handleSubmit}>
        <Input
          label="E-mail"
          type="email"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          required
          autoComplete="email"
        />
        <Select label="Papel" value={role} onChange={(event) => setRole(event.target.value)}>
          {INVITE_ROLES.map((value) => (
            <option key={value} value={value}>
              {value}
            </option>
          ))}
        </Select>

        {role === 'professional' && (
          <fieldset className="inline-fieldset">
            <legend>Vínculo com profissional</legend>
            <label className="inline-radio">
              <input
                type="radio"
                name="professionalMode"
                checked={professionalMode === 'new'}
                onChange={() => setProfessionalMode('new')}
              />
              Criar novo profissional
            </label>
            {professionalMode === 'new' && (
              <Input label="Nome do profissional" value={professionalName} onChange={(event) => setProfessionalName(event.target.value)} />
            )}
            <label className="inline-radio">
              <input
                type="radio"
                name="professionalMode"
                checked={professionalMode === 'existing'}
                onChange={() => setProfessionalMode('existing')}
                disabled={unlinkedProfessionals.length === 0}
              />
              Vincular a um profissional já cadastrado
            </label>
            {professionalMode === 'existing' && (
              <Select label="Profissional" value={professionalId} onChange={(event) => setProfessionalId(event.target.value)}>
                <option value="">Selecione…</option>
                {unlinkedProfessionals.map((professional) => (
                  <option key={professional.id} value={professional.id}>
                    {professional.name}
                  </option>
                ))}
              </Select>
            )}
          </fieldset>
        )}

        {error && <p className="form-error" role="alert">{error}</p>}

        <div className="modal-actions">
          <Button variant="secondary" onClick={onClose}>
            Fechar
          </Button>
          <Button type="submit" disabled={submitting}>
            {submitting ? 'Enviando…' : 'Enviar convite'}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
