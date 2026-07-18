import { Router } from 'express';
import { requireRole } from '../../middleware/requireRole.js';
import { createConvitesService } from './convites.service.js';
import { validateInvitePayload } from './convites.validation.js';

// Mirrors membership_set's actor_has_role check (private.actor_has_role
// requires 'owner') — a convite sempre termina em membership_set, então
// gatear a rota em qualquer outro papel só adiaria o 403 para o RPC.
const INVITE_ROLES = ['owner'];

export function convitesRouter({ supabaseAdmin, organizationContext, env }) {
  const router = Router();
  const service = createConvitesService(supabaseAdmin, env);

  router.use(organizationContext);

  router.post('/convites', requireRole(...INVITE_ROLES), async (req, res, next) => {
    try {
      const payload = validateInvitePayload(req.body);
      const invite = await service.invite({
        organizationId: req.auth.organizationId,
        actorUserId: req.auth.userId,
        ...payload,
      });
      res.status(201).json({ invite });
    } catch (err) {
      next(err);
    }
  });

  return router;
}
