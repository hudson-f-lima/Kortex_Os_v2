import { Router } from 'express';
import { createPspWebhookEventsService } from './pspWebhookEvents.service.js';
import { validatePspWebhookPayload } from './pspWebhookEvents.validation.js';

// Unauthenticated by design: PSPs don't carry our JWT/organization header.
// Must be mounted outside the authenticated apiRouter. Signature
// verification is out of scope for this fatia (no real PSP integration yet,
// per issues/002-payment-intents-webhook-outbox.md).
export function pspWebhookEventsRouter({ supabaseAdmin }) {
  const router = Router();
  const service = createPspWebhookEventsService(supabaseAdmin);

  router.post('/webhooks/psp', async (req, res, next) => {
    try {
      const parsed = validatePspWebhookPayload(req.body);
      const result = await service.ingest({ ...parsed, rawPayload: req.body });
      res.status(200).json(result);
    } catch (err) {
      next(err);
    }
  });

  return router;
}
