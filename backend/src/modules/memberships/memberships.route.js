import { Router } from 'express';
import { requireRole } from '../../middleware/requireRole.js';
import { validateId } from '../../shared/validation.js';
import { createMembershipsService } from './memberships.service.js';
import { validateMembershipPayload } from './memberships.validation.js';

// Mirrors RLS/RPC: memberships_select allows any active member; upserting a
// membership requires owner (membership_set's internal actor_has_role check).
const SET_ROLES = ['owner'];

export function membershipsRouter({ supabaseAdmin, organizationContext }) {
  const router = Router();
  const service = createMembershipsService(supabaseAdmin);

  router.use(organizationContext);

  router.get('/memberships', async (req, res, next) => {
    try {
      const memberships = await service.list({ organizationId: req.auth.organizationId });
      res.status(200).json({ memberships });
    } catch (err) {
      next(err);
    }
  });

  router.put('/memberships/:userId', requireRole(...SET_ROLES), async (req, res, next) => {
    try {
      const targetUserId = validateId(req.params.userId);
      const { role, active } = validateMembershipPayload(req.body);
      const membership = await service.set({
        organizationId: req.auth.organizationId,
        actorUserId: req.auth.userId,
        targetUserId,
        role,
        active,
      });
      res.status(200).json({ membership });
    } catch (err) {
      next(err);
    }
  });

  return router;
}
