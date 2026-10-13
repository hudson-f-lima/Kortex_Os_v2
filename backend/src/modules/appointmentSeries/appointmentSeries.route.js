import { Router } from 'express';
import { requireFeatureFlag } from '../../middleware/requireFeatureFlag.js';
import { requireRole } from '../../middleware/requireRole.js';
import { HttpError } from '../../shared/httpError.js';
import { validateIdempotencyKey } from '../../shared/validation.js';
import { createAppointmentSeriesService } from './appointmentSeries.service.js';
import { validateConflictId, validateSeriesCancel, validateSeriesCreate, validateSeriesExtend, validateSeriesId, validateSeriesUpdate } from './appointmentSeries.validation.js';

const WRITE_ROLES = ['owner', 'admin', 'manager', 'reception'];

function assertUnitScope(auth, unitId) {
  if (auth.unitId !== undefined && auth.unitId !== unitId) {
    throw HttpError.forbidden('unit_scope_mismatch', 'this membership is not scoped to the requested unit');
  }
}

function payloadForSeriesId(seriesId, payload) {
  return { ...payload, series_id: seriesId };
}

export function appointmentSeriesRouter({ supabaseAdmin, organizationContext }) {
  const router = Router();
  const service = createAppointmentSeriesService(supabaseAdmin);
  router.use(organizationContext);
  router.use(requireFeatureFlag(supabaseAdmin, 'recurring_group_waitlist_enabled'));

  async function scopedSeriesId(req) {
    const seriesId = validateSeriesId(req.params.seriesId);
    const unitId = await service.getSeriesUnit({ organizationId: req.auth.organizationId, seriesId });
    assertUnitScope(req.auth, unitId);
    return seriesId;
  }

  router.post('/appointment-series', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const payload = validateSeriesCreate(req.body);
      assertUnitScope(req.auth, payload.unit_id);
      const result = await service.create({ organizationId: req.auth.organizationId, actorUserId: req.auth.userId, idempotencyKey: validateIdempotencyKey(req.headers['idempotency-key']), payload });
      res.status(201).json(result);
    } catch (err) { next(err); }
  });

  router.post('/appointment-series/:seriesId/extend', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const seriesId = await scopedSeriesId(req);
      const result = await service.extend({ organizationId: req.auth.organizationId, actorUserId: req.auth.userId, idempotencyKey: validateIdempotencyKey(req.headers['idempotency-key']), payload: payloadForSeriesId(seriesId, validateSeriesExtend(req.body)) });
      res.status(200).json(result);
    } catch (err) { next(err); }
  });

  router.patch('/appointment-series/:seriesId', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const seriesId = await scopedSeriesId(req);
      const result = await service.update({ organizationId: req.auth.organizationId, actorUserId: req.auth.userId, idempotencyKey: validateIdempotencyKey(req.headers['idempotency-key']), payload: payloadForSeriesId(seriesId, validateSeriesUpdate(req.body)) });
      res.status(200).json(result);
    } catch (err) { next(err); }
  });

  router.post('/appointment-series/:seriesId/cancel', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const seriesId = await scopedSeriesId(req);
      const result = await service.cancel({ organizationId: req.auth.organizationId, actorUserId: req.auth.userId, idempotencyKey: validateIdempotencyKey(req.headers['idempotency-key']), payload: payloadForSeriesId(seriesId, validateSeriesCancel(req.body)) });
      res.status(200).json(result);
    } catch (err) { next(err); }
  });

  router.post('/appointment-series/:seriesId/conflicts/:conflictId/retry', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const seriesId = await scopedSeriesId(req);
      const result = await service.retryConflict({ organizationId: req.auth.organizationId, actorUserId: req.auth.userId, idempotencyKey: validateIdempotencyKey(req.headers['idempotency-key']), payload: { series_id: seriesId, conflict_id: validateConflictId(req.params.conflictId) } });
      res.status(200).json(result);
    } catch (err) { next(err); }
  });
  return router;
}
