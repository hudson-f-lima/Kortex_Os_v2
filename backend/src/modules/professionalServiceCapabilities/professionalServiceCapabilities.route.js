import { Router } from 'express';
import { HttpError } from '../../shared/httpError.js';
import { requireRole } from '../../middleware/requireRole.js';
import { validateCapability } from './professionalServiceCapabilities.validation.js';
import { createProfessionalServiceCapabilitiesService } from './professionalServiceCapabilities.service.js';

const WRITE_ROLES = ['owner', 'admin', 'manager'];
const DELETE_ROLES = ['owner', 'admin'];

export function professionalServiceCapabilitiesRouter({ supabaseAdmin, organizationContext }) {
  const router = Router();
  const service = createProfessionalServiceCapabilitiesService(supabaseAdmin);

  router.use(organizationContext);

  // GET /api/v1/professional-service-capabilities
  router.get('/professional-service-capabilities', async (req, res, next) => {
    try {
      const { professional_id, service_id } = req.query;
      const capabilities = await service.list({
        organizationId: req.auth.organizationId,
        professional_id,
        service_id,
      });
      res.json({ capabilities });
    } catch (err) {
      next(err);
    }
  });

  // GET /api/v1/professional-service-capabilities/:id
  router.get('/professional-service-capabilities/:id', async (req, res, next) => {
    try {
      const capability = await service.get({
        organizationId: req.auth.organizationId,
        capabilityId: req.params.id,
      });
      if (!capability) {
        return next(HttpError.notFound('capability_not_found', 'Capability not found'));
      }
      res.json({ capability });
    } catch (err) {
      next(err);
    }
  });

  // POST /api/v1/professional-service-capabilities
  router.post('/professional-service-capabilities', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const validation = validateCapability(req.body);
      if (!validation.valid) {
        return next(HttpError.badRequest('invalid_payload', 'Invalid capability payload', validation.errors));
      }

      const capability = await service.create({
        organizationId: req.auth.organizationId,
        payload: req.body,
      });
      res.status(201).json({ capability });
    } catch (err) {
      next(err);
    }
  });

  // PATCH /api/v1/professional-service-capabilities/:id
  router.patch('/professional-service-capabilities/:id', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const validation = validateCapability(req.body);
      if (!validation.valid) {
        return next(HttpError.badRequest('invalid_payload', 'Invalid capability payload', validation.errors));
      }

      const capability = await service.update({
        organizationId: req.auth.organizationId,
        capabilityId: req.params.id,
        payload: req.body,
      });
      if (!capability) {
        return next(HttpError.notFound('capability_not_found', 'Capability not found'));
      }
      res.json({ capability });
    } catch (err) {
      next(err);
    }
  });

  // DELETE /api/v1/professional-service-capabilities/:id
  router.delete('/professional-service-capabilities/:id', requireRole(...DELETE_ROLES), async (req, res, next) => {
    try {
      await service.delete({
        organizationId: req.auth.organizationId,
        capabilityId: req.params.id,
      });
      res.status(204).send();
    } catch (err) {
      next(err);
    }
  });

  return router;
}
