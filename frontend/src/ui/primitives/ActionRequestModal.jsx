import { Modal } from '../../shared/Modal.jsx';
import { Button } from './Button.jsx';
import { Badge } from './Badge.jsx';

/**
 * ActionRequestModal (Kortex.ai Human Governance Component - Master §6.3).
 * Renders AI-proposed sensitive actions (e.g. no-show fee waiver, commission override, fiado credit)
 * for manager review and one-click approval/rejection.
 *
 * @param {Object} props
 * @param {boolean} props.isOpen - Modal visibility
 * @param {Function} props.onClose - Callback on close/cancel
 * @param {Function} props.onApprove - Callback on approval
 * @param {Function} props.onReject - Callback on rejection
 * @param {Object} props.request - Action Request payload { title, description, category, impactCents, requestedBy }
 * @param {boolean} [props.submitting=false] - Pending state flag
 */
export function ActionRequestModal({
  isOpen,
  onClose,
  onApprove,
  onReject,
  request,
  submitting = false,
}) {
  if (!isOpen || !request) return null;

  const formattedImpact = request.impactCents
    ? (request.impactCents / 100).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })
    : null;

  return (
    <Modal onClose={onClose} title="Solicitação de Ação da IA" size="md">
      <div className="action-request-modal-content" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '0.5rem' }}>
          <span style={{ fontWeight: 600, fontSize: '1rem' }}>{request.title}</span>
          {request.category && <Badge variant="warning">{request.category}</Badge>}
        </div>

        <p style={{ margin: 0, fontSize: '0.875rem', color: 'var(--fg)', lineHeight: 1.5 }}>
          {request.description}
        </p>

        {formattedImpact && (
          <div
            style={{
              padding: '0.75rem',
              borderRadius: '8px',
              border: '1px solid var(--border)',
              background: 'color-mix(in srgb, var(--fg) 5%, var(--bg))',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              fontSize: '0.875rem',
            }}
          >
            <span style={{ color: 'var(--muted)' }}>Impacto Financeiro Estimado:</span>
            <strong style={{ fontSize: '1rem', color: 'var(--fg)' }}>{formattedImpact}</strong>
          </div>
        )}

        {request.requestedBy && (
          <span style={{ fontSize: '0.75rem', color: 'var(--muted)' }}>
            Sugerido por: {request.requestedBy}
          </span>
        )}

        <div className="modal-actions">
          <Button variant="outline" onClick={onReject} disabled={submitting}>
            Rejeitar
          </Button>
          <Button variant="primary" onClick={onApprove} loading={submitting}>
            Aprovar Ação
          </Button>
        </div>
      </div>
    </Modal>
  );
}
