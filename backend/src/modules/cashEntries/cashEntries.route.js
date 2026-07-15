import { Router } from 'express';
import { requireRole } from '../../middleware/requireRole.js';
import { validateIdempotencyKey } from '../../shared/validation.js';
import { HttpError } from '../../shared/httpError.js';
import { createCashEntriesService } from './cashEntries.service.js';

const KINDS = ['sale', 'income', 'expense', 'refund'];
const MANUAL_ENTRY_KINDS = ['income', 'expense'];

// Mirrors cash_entries_select (owner/admin/manager).
const READ_ROLES = ['owner', 'admin', 'manager'];
// Mirrors cash_entry_manual's internal actor_has_role check.
const WRITE_ROLES = ['owner', 'admin', 'manager'];

function parseOptionalKindQuery(value) {
  if (value === undefined) return undefined;
  if (typeof value !== 'string' || !KINDS.includes(value)) {
    throw HttpError.badRequest('invalid_kind', `kind query param must be one of: ${KINDS.join(', ')}`);
  }
  return value;
}

function validateManualEntryPayload(body) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    throw HttpError.badRequest('invalid_payload', 'payload must be a JSON object');
  }

  const allowed = new Set(['kind', 'amount_cents', 'description']);
  const unknown = Object.keys(body).filter((key) => !allowed.has(key));
  if (unknown.length > 0) {
    throw HttpError.badRequest('unknown_fields', 'payload has unsupported fields', { fields: unknown });
  }

  if (typeof body.kind !== 'string' || !MANUAL_ENTRY_KINDS.includes(body.kind)) {
    throw HttpError.badRequest('invalid_kind', `kind must be one of: ${MANUAL_ENTRY_KINDS.join(', ')}`);
  }

  if (!Number.isInteger(body.amount_cents) || body.amount_cents <= 0) {
    throw HttpError.badRequest('invalid_amount_cents', 'amount_cents must be a positive integer');
  }

  if (typeof body.description !== 'string' || body.description.trim().length === 0) {
    throw HttpError.badRequest('invalid_description', 'description must be a non-empty string');
  }

  return { kind: body.kind, amount_cents: body.amount_cents, description: body.description };
}

export function cashEntriesRouter({ supabaseAdmin, organizationContext }) {
  const router = Router();
  const service = createCashEntriesService(supabaseAdmin);

  router.use(organizationContext);

  router.get('/cash-entries', requireRole(...READ_ROLES), async (req, res, next) => {
    try {
      const entries = await service.list({
        organizationId: req.auth.organizationId,
        kind: parseOptionalKindQuery(req.query.kind),
      });
      res.status(200).json({ cash_entries: entries });
    } catch (err) {
      next(err);
    }
  });

  router.post('/cash-entries/manual', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const idempotencyKey = validateIdempotencyKey(req.headers['idempotency-key']);
      const { kind, amount_cents, description } = validateManualEntryPayload(req.body);
      const result = await service.createManualEntry({
        organizationId: req.auth.organizationId,
        actorUserId: req.auth.userId,
        idempotencyKey,
        kind,
        amountCents: amount_cents,
        description,
      });
      res.status(201).json(result);
    } catch (err) {
      next(err);
    }
  });

  return router;
}
