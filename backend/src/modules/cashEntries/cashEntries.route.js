import { Router } from 'express';
import { requireRole } from '../../middleware/requireRole.js';
import { HttpError } from '../../shared/httpError.js';
import { createCashEntriesService } from './cashEntries.service.js';

const KINDS = ['sale', 'income', 'expense', 'refund'];

// Mirrors cash_entries_select (owner/admin/manager).
const READ_ROLES = ['owner', 'admin', 'manager'];

function parseOptionalKindQuery(value) {
  if (value === undefined) return undefined;
  if (typeof value !== 'string' || !KINDS.includes(value)) {
    throw HttpError.badRequest('invalid_kind', `kind query param must be one of: ${KINDS.join(', ')}`);
  }
  return value;
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

  return router;
}
