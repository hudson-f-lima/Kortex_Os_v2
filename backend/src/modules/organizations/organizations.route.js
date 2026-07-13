import { Router } from 'express';
import { mapRpcError } from '../../shared/rpcError.js';
import { validateOrganizationPayload } from './organizations.validation.js';

export function organizationsRouter({ supabaseAdmin, organizationContext }) {
  const router = Router();

  // No organizationContext here: the caller has no membership yet — this is
  // the onboarding step that creates one (actor becomes owner).
  router.post('/organizations', async (req, res, next) => {
    try {
      const patch = validateOrganizationPayload(req.body);
      const { data, error } = await supabaseAdmin.rpc('create_organization', {
        p_actor_user_id: req.auth.userId,
        p_name: patch.name,
        p_slug: patch.slug,
      });
      if (error) throw mapRpcError(error);
      res.status(201).json({
        organization: { id: data.id, name: data.name, slug: data.slug, active: data.active },
        role: 'owner',
      });
    } catch (err) {
      next(err);
    }
  });

  router.get('/organizations', async (req, res, next) => {
    const { data, error } = await supabaseAdmin
      .from('memberships')
      .select('role, organization_id, organizations!inner(id, name, slug, active)')
      .eq('user_id', req.auth.userId)
      .eq('active', true)
      .eq('organizations.active', true);

    if (error) {
      next(error);
      return;
    }

    res.status(200).json({
      organizations: data.map((row) => ({
        id: row.organizations.id,
        name: row.organizations.name,
        slug: row.organizations.slug,
        role: row.role,
      })),
    });
  });

  router.get('/organizations/current', organizationContext, (req, res) => {
    res.status(200).json({
      organization_id: req.auth.organizationId,
      role: req.auth.role,
    });
  });

  return router;
}
