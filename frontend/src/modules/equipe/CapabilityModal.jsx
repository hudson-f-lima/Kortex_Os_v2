import { useState } from 'react';
import { ApiError } from '../../shared/apiClient.js';

function messageForError(err) {
  if (err instanceof ApiError) return err.message;
  return 'Erro ao salvar capacidade.';
}

export function CapabilityModal({ capability, professionals, services, apiClient, onClose, onSaved }) {
  const [formData, setFormData] = useState({
    professional_id: capability?.professional_id || '',
    service_id: capability?.service_id || '',
    duration_override_minutes: capability?.duration_override_minutes ?? '',
    buffer_before_min: capability?.buffer_before_min || 0,
    buffer_after_min: capability?.buffer_after_min || 0,
    price_override_cents: capability?.price_override_cents ?? '',
  });
  const [errors, setErrors] = useState({});
  const [saving, setSaving] = useState(false);

  function validate() {
    const newErrors = {};

    if (!formData.professional_id) {
      newErrors.professional_id = 'Profissional é obrigatório';
    }
    if (!formData.service_id) {
      newErrors.service_id = 'Serviço é obrigatório';
    }

    if (formData.duration_override_minutes !== '') {
      const dur = Number(formData.duration_override_minutes);
      if (!Number.isInteger(dur) || dur < 5 || dur > 1440) {
        newErrors.duration_override_minutes = 'Duração deve ser entre 5 e 1440 minutos';
      }
    }

    ['buffer_before_min', 'buffer_after_min'].forEach((field) => {
      const val = Number(formData[field]);
      if (isNaN(val) || val < 0 || val > 480) {
        newErrors[field] = 'Buffer deve ser entre 0 e 480 minutos';
      }
    });

    if (formData.price_override_cents !== '') {
      const price = Number(formData.price_override_cents);
      if (!Number.isInteger(price) || price < 0) {
        newErrors.price_override_cents = 'Preço deve ser um valor inteiro em centavos';
      }
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  }

  async function handleSubmit(e) {
    e.preventDefault();
    if (!validate()) return;

    setSaving(true);
    try {
      const payload = {
        professional_id: formData.professional_id,
        service_id: formData.service_id,
        duration_override_minutes: formData.duration_override_minutes ? Number(formData.duration_override_minutes) : null,
        buffer_before_min: Number(formData.buffer_before_min) || 0,
        buffer_after_min: Number(formData.buffer_after_min) || 0,
        price_override_cents: formData.price_override_cents ? Number(formData.price_override_cents) : null,
      };
      await onSaved(payload);
    } catch (err) {
      setErrors({ form: messageForError(err) });
    } finally {
      setSaving(false);
    }
  }

  return (
    <div style={modalOverlayStyle}>
      <div style={modalStyle}>
        <h2>{capability ? 'Editar Capacidade' : 'Nova Capacidade'}</h2>

        {errors.form && <p style={{ color: 'var(--color-danger)' }}>{errors.form}</p>}

        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label htmlFor="professional">
              Profissional *
              <select
                id="professional"
                value={formData.professional_id}
                onChange={(e) => setFormData({ ...formData, professional_id: e.target.value })}
                disabled={!!capability}
                required
              >
                <option value="">Selecione um profissional</option>
                {professionals?.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.name}
                  </option>
                ))}
              </select>
              {errors.professional_id && <span style={{ color: 'var(--color-danger)' }}>{errors.professional_id}</span>}
            </label>
          </div>

          <div className="form-group">
            <label htmlFor="service">
              Serviço *
              <select
                id="service"
                value={formData.service_id}
                onChange={(e) => setFormData({ ...formData, service_id: e.target.value })}
                disabled={!!capability}
                required
              >
                <option value="">Selecione um serviço</option>
                {services?.map((s) => (
                  <option key={s.id} value={s.id}>
                    {s.name}
                  </option>
                ))}
              </select>
              {errors.service_id && <span style={{ color: 'var(--color-danger)' }}>{errors.service_id}</span>}
            </label>
          </div>

          <div className="form-group">
            <label htmlFor="duration">
              Duração Customizada (minutos)
              <input
                id="duration"
                type="number"
                min="5"
                max="1440"
                value={formData.duration_override_minutes}
                onChange={(e) => setFormData({ ...formData, duration_override_minutes: e.target.value })}
                placeholder="Deixe vazio para usar a duração do serviço"
              />
              {errors.duration_override_minutes && (
                <span style={{ color: 'var(--color-danger)' }}>{errors.duration_override_minutes}</span>
              )}
            </label>
          </div>

          <div className="form-group">
            <label htmlFor="price">
              Preço Customizado (em centavos)
              <input
                id="price"
                type="number"
                min="0"
                value={formData.price_override_cents}
                onChange={(e) => setFormData({ ...formData, price_override_cents: e.target.value })}
                placeholder="Deixe vazio para usar o preço do serviço"
              />
              {errors.price_override_cents && (
                <span style={{ color: 'var(--color-danger)' }}>{errors.price_override_cents}</span>
              )}
            </label>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
            <div className="form-group">
              <label htmlFor="bufferBefore">
                Buffer Antes (minutos)
                <input
                  id="bufferBefore"
                  type="number"
                  min="0"
                  max="480"
                  value={formData.buffer_before_min}
                  onChange={(e) => setFormData({ ...formData, buffer_before_min: Number(e.target.value) })}
                />
                {errors.buffer_before_min && (
                  <span style={{ color: 'var(--color-danger)' }}>{errors.buffer_before_min}</span>
                )}
              </label>
            </div>

            <div className="form-group">
              <label htmlFor="bufferAfter">
                Buffer Depois (minutos)
                <input
                  id="bufferAfter"
                  type="number"
                  min="0"
                  max="480"
                  value={formData.buffer_after_min}
                  onChange={(e) => setFormData({ ...formData, buffer_after_min: Number(e.target.value) })}
                />
                {errors.buffer_after_min && (
                  <span style={{ color: 'var(--color-danger)' }}>{errors.buffer_after_min}</span>
                )}
              </label>
            </div>
          </div>

          <div style={{ display: 'flex', gap: '0.5rem', justifyContent: 'flex-end', marginTop: '1rem' }}>
            <button type="button" onClick={onClose} disabled={saving}>
              Cancelar
            </button>
            <button type="submit" disabled={saving}>
              {saving ? 'Salvando…' : 'Salvar'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

const modalOverlayStyle = {
  position: 'fixed',
  top: 0,
  left: 0,
  right: 0,
  bottom: 0,
  backgroundColor: 'rgba(0, 0, 0, 0.5)',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  zIndex: 1000,
};

const modalStyle = {
  backgroundColor: 'white',
  borderRadius: '0.5rem',
  padding: '2rem',
  maxWidth: '500px',
  width: '90%',
  maxHeight: '90vh',
  overflowY: 'auto',
};
