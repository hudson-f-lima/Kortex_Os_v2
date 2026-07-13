import { Router } from 'express';
import { requireRole } from '../../middleware/requireRole.js';
import { createPackagesService } from './packages.service.js';
import { validateCreatePackagePayload, validatePackageId, validateUpdatePackagePayload } from './packages.validation.js';

// Mirrors the create_package/update_package RPC's internal actor_has_role
// check (owner/admin/manager) and packages_delete RLS (owner/admin), same
// shape as services/service_groups.
const WRITE_ROLES = ['owner', 'admin', 'manager'];
const DELETE_ROLES = ['owner', 'admin'];

export function packagesRouter({ supabaseAdmin, organizationContext }) {
  const router = Router();
  const service = createPackagesService(supabaseAdmin);

  router.use(organizationContext);

  router.get('/packages', async (req, res, next) => {
    try {
      const { active } = req.query;
      const packages = await service.list({
        organizationId: req.auth.organizationId,
        active: active === undefined ? undefined : active === 'true',
      });
      res.status(200).json({ packages });
    } catch (err) {
      next(err);
    }
  });

  router.get('/packages/:id', async (req, res, next) => {
    try {
      const packageId = validatePackageId(req.params.id);
      const result = await service.get({ organizationId: req.auth.organizationId, packageId });
      res.status(200).json({ package: result });
    } catch (err) {
      next(err);
    }
  });

  router.post('/packages', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const payload = validateCreatePackagePayload(req.body);
      const result = await service.create({
        organizationId: req.auth.organizationId,
        actorUserId: req.auth.userId,
        payload,
      });
      res.status(201).json({ package: result });
    } catch (err) {
      next(err);
    }
  });

  router.patch('/packages/:id', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const packageId = validatePackageId(req.params.id);
      const patch = validateUpdatePackagePayload(req.body);
      const result = await service.update({
        organizationId: req.auth.organizationId,
        actorUserId: req.auth.userId,
        packageId,
        patch,
      });
      res.status(200).json({ package: result });
    } catch (err) {
      next(err);
    }
  });

  router.delete('/packages/:id', requireRole(...DELETE_ROLES), async (req, res, next) => {
    try {
      const packageId = validatePackageId(req.params.id);
      await service.remove({ organizationId: req.auth.organizationId, packageId });
      res.status(204).send();
    } catch (err) {
      next(err);
    }
  });

  return router;
}
