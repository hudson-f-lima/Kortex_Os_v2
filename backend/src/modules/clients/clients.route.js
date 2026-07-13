import { Router } from 'express';
import { requireRole } from '../../middleware/requireRole.js';
import { createClientsService } from './clients.service.js';
import { validateClientId, validateClientPayload } from './clients.validation.js';

// Mirrors the RLS role allowlists on public.clients (defense in depth):
// clients_select / clients_insert / clients_update / clients_delete.
const READ_ROLES = ['owner', 'admin', 'manager', 'reception'];
const WRITE_ROLES = ['owner', 'admin', 'manager', 'reception'];
const DELETE_ROLES = ['owner', 'admin', 'manager'];

export function clientsRouter({ supabaseAdmin, organizationContext }) {
  const router = Router();
  const service = createClientsService(supabaseAdmin);

  router.use(organizationContext);

  router.get('/clients', requireRole(...READ_ROLES), async (req, res, next) => {
    try {
      const { active } = req.query;
      const clients = await service.list({
        organizationId: req.auth.organizationId,
        active: active === undefined ? undefined : active === 'true',
      });
      res.status(200).json({ clients });
    } catch (err) {
      next(err);
    }
  });

  router.get('/clients/:id', requireRole(...READ_ROLES), async (req, res, next) => {
    try {
      const clientId = validateClientId(req.params.id);
      const client = await service.get({ organizationId: req.auth.organizationId, clientId });
      res.status(200).json({ client });
    } catch (err) {
      next(err);
    }
  });

  router.post('/clients', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const patch = validateClientPayload(req.body, { requireName: true });
      const client = await service.create({
        organizationId: req.auth.organizationId,
        actorUserId: req.auth.userId,
        patch,
      });
      res.status(201).json({ client });
    } catch (err) {
      next(err);
    }
  });

  router.patch('/clients/:id', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const clientId = validateClientId(req.params.id);
      const patch = validateClientPayload(req.body, { requireName: false });
      const client = await service.update({ organizationId: req.auth.organizationId, clientId, patch });
      res.status(200).json({ client });
    } catch (err) {
      next(err);
    }
  });

  router.delete('/clients/:id', requireRole(...DELETE_ROLES), async (req, res, next) => {
    try {
      const clientId = validateClientId(req.params.id);
      await service.remove({ organizationId: req.auth.organizationId, clientId });
      res.status(204).send();
    } catch (err) {
      next(err);
    }
  });

  return router;
}
