import { Router } from 'express';
import { requireRole } from '../../middleware/requireRole.js';
import { createProfessionalsService } from './professionals.service.js';
import { validateProfessionalId, validateProfessionalPayload } from './professionals.validation.js';

// Mirrors the RLS role allowlists on public.professionals (defense in depth):
// professionals_select allows any active member; insert/update require
// owner/admin/manager; delete requires owner/admin.
const WRITE_ROLES = ['owner', 'admin', 'manager'];
const DELETE_ROLES = ['owner', 'admin'];

export function professionalsRouter({ supabaseAdmin, organizationContext }) {
  const router = Router();
  const service = createProfessionalsService(supabaseAdmin);

  router.use(organizationContext);

  router.get('/professionals', async (req, res, next) => {
    try {
      const { active } = req.query;
      const professionals = await service.list({
        organizationId: req.auth.organizationId,
        active: active === undefined ? undefined : active === 'true',
      });
      res.status(200).json({ professionals });
    } catch (err) {
      next(err);
    }
  });

  router.get('/professionals/:id', async (req, res, next) => {
    try {
      const professionalId = validateProfessionalId(req.params.id);
      const professional = await service.get({ organizationId: req.auth.organizationId, professionalId });
      res.status(200).json({ professional });
    } catch (err) {
      next(err);
    }
  });

  router.post('/professionals', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const patch = validateProfessionalPayload(req.body, { requireName: true });
      const professional = await service.create({ organizationId: req.auth.organizationId, patch });
      res.status(201).json({ professional });
    } catch (err) {
      next(err);
    }
  });

  router.patch('/professionals/:id', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const professionalId = validateProfessionalId(req.params.id);
      const patch = validateProfessionalPayload(req.body, { requireName: false });
      const professional = await service.update({
        organizationId: req.auth.organizationId,
        professionalId,
        patch,
      });
      res.status(200).json({ professional });
    } catch (err) {
      next(err);
    }
  });

  router.delete('/professionals/:id', requireRole(...DELETE_ROLES), async (req, res, next) => {
    try {
      const professionalId = validateProfessionalId(req.params.id);
      await service.remove({ organizationId: req.auth.organizationId, professionalId });
      res.status(204).send();
    } catch (err) {
      next(err);
    }
  });

  return router;
}
