import { Router } from 'express';
import { requireFeatureFlag } from '../../middleware/requireFeatureFlag.js';
import { UUID_RE } from '../../shared/validation.js';
import { HttpError } from '../../shared/httpError.js';
import { createAvailabilityService } from './availability.service.js';
import { validateAvailabilityQuery } from './availability.validation.js';

// Rota nova e isolada (Blueprint Onda 4 §3.4/§3.6) — não modifica
// create_appointment/checkout_close nem nenhuma rota existente. Primeira
// rota desta trilha efetivamente gated por uma feature flag real
// (`availability_resolver_enabled`); a Onda 3 escreveu chaves sem rota
// nenhuma para governar ainda.
export function availabilityRouter({ supabaseAdmin, organizationContext }) {
  const router = Router();
  const service = createAvailabilityService(supabaseAdmin);

  router.use(organizationContext);
  router.use(requireFeatureFlag(supabaseAdmin, 'availability_resolver_enabled'));

  router.get('/units/:unitId/availability', async (req, res, next) => {
    try {
      if (typeof req.params.unitId !== 'string' || !UUID_RE.test(req.params.unitId)) {
        throw HttpError.badRequest('invalid_unit_id', 'unitId path param must be a uuid');
      }
      // Mirrors can_access_fact_unit (RLS): org-wide roles (owner/admin/manager)
      // have req.auth.unitId === undefined and may query any unit; unit-scoped
      // roles (reception/professional) must match their own membership unit.
      // Achado do Red Team pós-implementação (2026-07-29): esta checagem
      // estava ausente — supabaseAdmin usa service_role e ignora RLS, então
      // nada mais protegia isso; reception de uma unidade conseguia consultar
      // outra unidade da mesma organização.
      if (req.auth.unitId !== undefined && req.auth.unitId !== req.params.unitId) {
        throw HttpError.forbidden('unit_scope_mismatch', 'this membership is not scoped to the requested unit');
      }
      const { serviceId, professionalId, dateFrom, dateTo } = validateAvailabilityQuery(req.query);

      const availability = await service.getSlots({
        organizationId: req.auth.organizationId,
        unitId: req.params.unitId,
        serviceId,
        professionalId,
        dateFrom,
        dateTo,
      });

      res.status(200).json({ availability });
    } catch (err) {
      next(err);
    }
  });

  return router;
}
