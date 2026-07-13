import { Router } from 'express';
import { requireRole } from '../../middleware/requireRole.js';
import { createServiceGroupsService } from './serviceGroups.service.js';
import { validateServiceGroupId, validateServiceGroupPayload } from './serviceGroups.validation.js';

// Mirrors RLS on public.service_groups (defense in depth): service_groups_select
// allows any active member; insert/update require owner/admin/manager; delete
// requires owner/admin — same shape as services.
const WRITE_ROLES = ['owner', 'admin', 'manager'];
const DELETE_ROLES = ['owner', 'admin'];

export function serviceGroupsRouter({ supabaseAdmin, organizationContext }) {
  const router = Router();
  const service = createServiceGroupsService(supabaseAdmin);

  router.use(organizationContext);

  router.get('/service-groups', async (req, res, next) => {
    try {
      const { active } = req.query;
      const serviceGroups = await service.list({
        organizationId: req.auth.organizationId,
        active: active === undefined ? undefined : active === 'true',
      });
      res.status(200).json({ service_groups: serviceGroups });
    } catch (err) {
      next(err);
    }
  });

  router.get('/service-groups/:id', async (req, res, next) => {
    try {
      const serviceGroupId = validateServiceGroupId(req.params.id);
      const result = await service.get({ organizationId: req.auth.organizationId, serviceGroupId });
      res.status(200).json({ service_group: result });
    } catch (err) {
      next(err);
    }
  });

  router.post('/service-groups', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const patch = validateServiceGroupPayload(req.body, { requireAll: true });
      const result = await service.create({ organizationId: req.auth.organizationId, patch });
      res.status(201).json({ service_group: result });
    } catch (err) {
      next(err);
    }
  });

  router.patch('/service-groups/:id', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const serviceGroupId = validateServiceGroupId(req.params.id);
      const patch = validateServiceGroupPayload(req.body, { requireAll: false });
      const result = await service.update({ organizationId: req.auth.organizationId, serviceGroupId, patch });
      res.status(200).json({ service_group: result });
    } catch (err) {
      next(err);
    }
  });

  router.delete('/service-groups/:id', requireRole(...DELETE_ROLES), async (req, res, next) => {
    try {
      const serviceGroupId = validateServiceGroupId(req.params.id);
      await service.remove({ organizationId: req.auth.organizationId, serviceGroupId });
      res.status(204).send();
    } catch (err) {
      next(err);
    }
  });

  return router;
}
