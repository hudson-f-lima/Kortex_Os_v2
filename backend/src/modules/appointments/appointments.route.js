import { Router } from 'express';
import { requireRole } from '../../middleware/requireRole.js';
import { HttpError } from '../../shared/httpError.js';
import { UUID_RE, validateIdempotencyKey } from '../../shared/validation.js';
import { createAppointmentsService } from './appointments.service.js';
import {
  APPOINTMENT_STATUSES,
  validateAppointmentId,
  validateAppointmentPayload,
} from './appointments.validation.js';

// Mirrors RLS on public.appointments (defense in depth): appointments_select
// allows any active member; insert/update/delete all require
// owner/admin/manager/reception (delete is not further restricted here).
const WRITE_ROLES = ['owner', 'admin', 'manager', 'reception'];
const DELETE_ROLES = ['owner', 'admin', 'manager', 'reception'];

function parseOptionalUuidQuery(value, fieldName) {
  if (value === undefined) return undefined;
  if (typeof value !== 'string' || !UUID_RE.test(value)) {
    throw HttpError.badRequest(`invalid_${fieldName}`, `${fieldName} query param must be a uuid`);
  }
  return value;
}

function parseOptionalStatusQuery(value) {
  if (value === undefined) return undefined;
  if (typeof value !== 'string' || !APPOINTMENT_STATUSES.includes(value)) {
    throw HttpError.badRequest('invalid_status', `status query param must be one of: ${APPOINTMENT_STATUSES.join(', ')}`);
  }
  return value;
}

export function appointmentsRouter({ supabaseAdmin, organizationContext }) {
  const router = Router();
  const service = createAppointmentsService(supabaseAdmin);

  router.use(organizationContext);

  router.get('/appointments', async (req, res, next) => {
    try {
      const appointments = await service.list({
        organizationId: req.auth.organizationId,
        professionalId: parseOptionalUuidQuery(req.query.professional_id, 'professional_id'),
        clientId: parseOptionalUuidQuery(req.query.client_id, 'client_id'),
        status: parseOptionalStatusQuery(req.query.status),
        from: req.query.from,
        to: req.query.to,
      });
      res.status(200).json({ appointments });
    } catch (err) {
      next(err);
    }
  });

  router.get('/appointments/:id', async (req, res, next) => {
    try {
      const appointmentId = validateAppointmentId(req.params.id);
      const appointment = await service.get({ organizationId: req.auth.organizationId, appointmentId });
      res.status(200).json({ appointment });
    } catch (err) {
      next(err);
    }
  });

  router.post('/appointments', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const idempotencyKey = validateIdempotencyKey(req.headers['idempotency-key']);
      const patch = validateAppointmentPayload(req.body, { requireAll: true });
      const appointment = await service.create({
        organizationId: req.auth.organizationId,
        actorUserId: req.auth.userId,
        idempotencyKey,
        patch,
      });
      res.status(201).json({ appointment });
    } catch (err) {
      next(err);
    }
  });

  router.patch('/appointments/:id', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const idempotencyKey = validateIdempotencyKey(req.headers['idempotency-key']);
      const appointmentId = validateAppointmentId(req.params.id);
      const patch = validateAppointmentPayload(req.body, { requireAll: false });
      const appointment = await service.update({
        organizationId: req.auth.organizationId,
        actorUserId: req.auth.userId,
        appointmentId,
        idempotencyKey,
        patch,
      });
      res.status(200).json({ appointment });
    } catch (err) {
      next(err);
    }
  });

  router.delete('/appointments/:id', requireRole(...DELETE_ROLES), async (req, res, next) => {
    try {
      const appointmentId = validateAppointmentId(req.params.id);
      await service.remove({ organizationId: req.auth.organizationId, appointmentId });
      res.status(204).send();
    } catch (err) {
      next(err);
    }
  });

  return router;
}
