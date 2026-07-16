import { Router } from 'express';
import { requireRole } from '../../middleware/requireRole.js';
import { HttpError } from '../../shared/httpError.js';
import { UUID_RE } from '../../shared/validation.js';
import { createProfessionalServiceCapabilitiesService } from './professionalServiceCapabilities.service.js';
import {
  validateCapabilityId,
  validateCreateCapabilityPayload,
  validateUpdateCapabilityPayload,
} from './professionalServiceCapabilities.validation.js';

// Mirrors RLS on public.professional_service_capabilities (defense in depth):
// select allows any active member; insert/update require owner/admin/manager;
// delete requires owner/admin.
const WRITE_ROLES = ['owner', 'admin', 'manager'];
const DELETE_ROLES = ['owner', 'admin'];

function parseOptionalUuidQuery(value, fieldName) {
  if (value === undefined) return undefined;
  if (typeof value !== 'string' || !UUID_RE.test(value)) {
    throw HttpError.badRequest(`invalid_${fieldName}`, `${fieldName} query param must be a uuid`);
  }
  return value;
}

export function professionalServiceCapabilitiesRouter({ supabaseAdmin, organizationContext }) {
  const router = Router();
  const service = createProfessionalServiceCapabilitiesService(supabaseAdmin);

  router.use(organizationContext);

  router.get('/professional-service-capabilities', async (req, res, next) => {
    try {
      const capabilities = await service.list({
        organizationId: req.auth.organizationId,
        professionalId: parseOptionalUuidQuery(req.query.professional_id, 'professional_id'),
        serviceId: parseOptionalUuidQuery(req.query.service_id, 'service_id'),
      });
      res.status(200).json({ professional_service_capabilities: capabilities });
    } catch (err) {
      next(err);
    }
  });

  router.get('/professional-service-capabilities/:id', async (req, res, next) => {
    try {
      const id = validateCapabilityId(req.params.id);
      const capability = await service.get({ organizationId: req.auth.organizationId, id });
      res.status(200).json({ professional_service_capability: capability });
    } catch (err) {
      next(err);
    }
  });

  router.post('/professional-service-capabilities', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const patch = validateCreateCapabilityPayload(req.body);
      const capability = await service.create({ organizationId: req.auth.organizationId, patch });
      res.status(201).json({ professional_service_capability: capability });
    } catch (err) {
      next(err);
    }
  });

  router.patch('/professional-service-capabilities/:id', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const id = validateCapabilityId(req.params.id);
      const patch = validateUpdateCapabilityPayload(req.body);
      const capability = await service.update({ organizationId: req.auth.organizationId, id, patch });
      res.status(200).json({ professional_service_capability: capability });
    } catch (err) {
      next(err);
    }
  });

  router.delete('/professional-service-capabilities/:id', requireRole(...DELETE_ROLES), async (req, res, next) => {
    try {
      const id = validateCapabilityId(req.params.id);
      await service.remove({ organizationId: req.auth.organizationId, id });
      res.status(204).send();
    } catch (err) {
      next(err);
    }
  });

  return router;
}
