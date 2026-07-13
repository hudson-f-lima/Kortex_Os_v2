import { Router } from 'express';
import { requireRole } from '../../middleware/requireRole.js';
import { HttpError } from '../../shared/httpError.js';
import { UUID_RE } from '../../shared/validation.js';
import { createProfessionalServiceCommissionsService } from './professionalCommissions.service.js';
import {
  validateCreateProfessionalServiceCommissionPayload,
  validateProfessionalServiceCommissionId,
  validateUpdateProfessionalServiceCommissionPayload,
} from './professionalCommissions.validation.js';

// Mirrors RLS on public.professional_service_commissions (defense in depth):
// select allows any active member; insert/update require owner/admin/manager;
// delete requires owner/admin — no reception, this is financial data (same
// shape as cash_entries).
const WRITE_ROLES = ['owner', 'admin', 'manager'];
const DELETE_ROLES = ['owner', 'admin'];

function parseOptionalUuidQuery(value, fieldName) {
  if (value === undefined) return undefined;
  if (typeof value !== 'string' || !UUID_RE.test(value)) {
    throw HttpError.badRequest(`invalid_${fieldName}`, `${fieldName} query param must be a uuid`);
  }
  return value;
}

export function professionalCommissionsRouter({ supabaseAdmin, organizationContext }) {
  const router = Router();
  const service = createProfessionalServiceCommissionsService(supabaseAdmin);

  router.use(organizationContext);

  router.get('/professional-service-commissions', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const commissions = await service.list({
        organizationId: req.auth.organizationId,
        professionalId: parseOptionalUuidQuery(req.query.professional_id, 'professional_id'),
        serviceId: parseOptionalUuidQuery(req.query.service_id, 'service_id'),
      });
      res.status(200).json({ professional_service_commissions: commissions });
    } catch (err) {
      next(err);
    }
  });

  router.get('/professional-service-commissions/:id', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const id = validateProfessionalServiceCommissionId(req.params.id);
      const commission = await service.get({ organizationId: req.auth.organizationId, id });
      res.status(200).json({ professional_service_commission: commission });
    } catch (err) {
      next(err);
    }
  });

  router.post('/professional-service-commissions', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const patch = validateCreateProfessionalServiceCommissionPayload(req.body);
      const commission = await service.create({ organizationId: req.auth.organizationId, patch });
      res.status(201).json({ professional_service_commission: commission });
    } catch (err) {
      next(err);
    }
  });

  router.patch('/professional-service-commissions/:id', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const id = validateProfessionalServiceCommissionId(req.params.id);
      const patch = validateUpdateProfessionalServiceCommissionPayload(req.body);
      const commission = await service.update({ organizationId: req.auth.organizationId, id, patch });
      res.status(200).json({ professional_service_commission: commission });
    } catch (err) {
      next(err);
    }
  });

  router.delete('/professional-service-commissions/:id', requireRole(...DELETE_ROLES), async (req, res, next) => {
    try {
      const id = validateProfessionalServiceCommissionId(req.params.id);
      await service.remove({ organizationId: req.auth.organizationId, id });
      res.status(204).send();
    } catch (err) {
      next(err);
    }
  });

  return router;
}
