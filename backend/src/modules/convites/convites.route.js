import { Router } from 'express';
import { requireRole } from '../../middleware/requireRole.js';
import { createConvitesService } from './convites.service.js';
import { validateInvitePayload } from './convites.validation.js';

// The invitation flow ends in membership_scope_set; owner-only at the route
// keeps the public API stricter than the owner/admin RPC contract.
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
