import { Router } from 'express';
import { requireRole } from '../../middleware/requireRole.js';
import { HttpError } from '../../shared/httpError.js';
import { UUID_RE } from '../../shared/validation.js';
import { createProfessionalServiceGroupEligibilityService } from './professionalServiceGroupEligibility.service.js';
import {
  validateCreateGroupEligibilityPayload,
  validateGroupEligibilityId,
  validateUpdateGroupEligibilityPayload,
} from './professionalServiceGroupEligibility.validation.js';

// Mirrors RLS on public.professional_service_group_eligibility (defense in
// depth): select allows any active member; insert/update require
// owner/admin/manager; delete requires owner/admin.
const WRITE_ROLES = ['owner', 'admin', 'manager'];
const DELETE_ROLES = ['owner', 'admin'];

function parseOptionalUuidQuery(value, fieldName) {
  if (value === undefined) return undefined;
  if (typeof value !== 'string' || !UUID_RE.test(value)) {
    throw HttpError.badRequest(`invalid_${fieldName}`, `${fieldName} query param must be a uuid`);
  }
  return value;
}

export function professionalServiceGroupEligibilityRouter({ supabaseAdmin, organizationContext }) {
  const router = Router();
  const service = createProfessionalServiceGroupEligibilityService(supabaseAdmin);

  router.use(organizationContext);

  router.get('/professional-service-group-eligibility', async (req, res, next) => {
    try {
      const rows = await service.list({
        organizationId: req.auth.organizationId,
        professionalId: parseOptionalUuidQuery(req.query.professional_id, 'professional_id'),
        serviceGroupId: parseOptionalUuidQuery(req.query.service_group_id, 'service_group_id'),
      });
      res.status(200).json({ professional_service_group_eligibility: rows });
    } catch (err) {
      next(err);
    }
  });

  router.get('/professional-service-group-eligibility/:id', async (req, res, next) => {
    try {
      const id = validateGroupEligibilityId(req.params.id);
      const row = await service.get({ organizationId: req.auth.organizationId, id });
      res.status(200).json({ professional_service_group_eligibility: row });
    } catch (err) {
      next(err);
    }
  });

  router.post('/professional-service-group-eligibility', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const patch = validateCreateGroupEligibilityPayload(req.body);
      const row = await service.create({ organizationId: req.auth.organizationId, patch });
      res.status(201).json({ professional_service_group_eligibility: row });
    } catch (err) {
      next(err);
    }
  });

  router.patch('/professional-service-group-eligibility/:id', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const id = validateGroupEligibilityId(req.params.id);
      const patch = validateUpdateGroupEligibilityPayload(req.body);
      const row = await service.update({ organizationId: req.auth.organizationId, id, patch });
      res.status(200).json({ professional_service_group_eligibility: row });
    } catch (err) {
      next(err);
    }
  });

  router.delete('/professional-service-group-eligibility/:id', requireRole(...DELETE_ROLES), async (req, res, next) => {
    try {
      const id = validateGroupEligibilityId(req.params.id);
      await service.remove({ organizationId: req.auth.organizationId, id });
      res.status(204).send();
    } catch (err) {
      next(err);
    }
  });

  return router;
}
