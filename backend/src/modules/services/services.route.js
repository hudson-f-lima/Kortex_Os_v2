import { Router } from 'express';
import { requireRole } from '../../middleware/requireRole.js';
import { createServicesService } from './services.service.js';
import { validateServiceId, validateServicePayload } from './services.validation.js';

// Mirrors RLS on public.services (defense in depth): services_select allows
// any active member; insert/update require owner/admin/manager; delete
// requires owner/admin.
const WRITE_ROLES = ['owner', 'admin', 'manager'];
const DELETE_ROLES = ['owner', 'admin'];

export function servicesRouter({ supabaseAdmin, organizationContext }) {
  const router = Router();
  const service = createServicesService(supabaseAdmin);

  router.use(organizationContext);

  router.get('/services', async (req, res, next) => {
    try {
      const { active } = req.query;
      const services = await service.list({
        organizationId: req.auth.organizationId,
        active: active === undefined ? undefined : active === 'true',
      });
      res.status(200).json({ services });
    } catch (err) {
      next(err);
    }
  });

  router.get('/services/:id', async (req, res, next) => {
    try {
      const serviceId = validateServiceId(req.params.id);
      const result = await service.get({ organizationId: req.auth.organizationId, serviceId });
      res.status(200).json({ service: result });
    } catch (err) {
      next(err);
    }
  });

  router.post('/services', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const patch = validateServicePayload(req.body, { requireAll: true });
      const result = await service.create({ organizationId: req.auth.organizationId, patch });
      res.status(201).json({ service: result });
    } catch (err) {
      next(err);
    }
  });

  router.patch('/services/:id', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const serviceId = validateServiceId(req.params.id);
      const patch = validateServicePayload(req.body, { requireAll: false });
      const result = await service.update({ organizationId: req.auth.organizationId, serviceId, patch });
      res.status(200).json({ service: result });
    } catch (err) {
      next(err);
    }
  });

  router.delete('/services/:id', requireRole(...DELETE_ROLES), async (req, res, next) => {
    try {
      const serviceId = validateServiceId(req.params.id);
      await service.remove({ organizationId: req.auth.organizationId, serviceId });
      res.status(204).send();
    } catch (err) {
      next(err);
    }
  });

  return router;
}
