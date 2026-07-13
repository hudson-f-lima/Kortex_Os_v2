import { Router } from 'express';

export function organizationsRouter({ supabaseAdmin, organizationContext }) {
  const router = Router();

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
