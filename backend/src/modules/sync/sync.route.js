import { Router } from 'express';
import { requireRole } from '../../middleware/requireRole.js';
import { createSyncService } from './sync.service.js';

const ALL_ROLES = ['owner', 'admin', 'manager', 'reception', 'professional'];

export function syncRouter({ supabaseAdmin, organizationContext }) {
  const router = Router();
  const service = createSyncService(supabaseAdmin);

  router.use(organizationContext);

  router.get('/sync', requireRole(...ALL_ROLES), async (req, res, next) => {
    try {
      const sinceId = parseInt(req.query.since ?? '0', 10);
      if (isNaN(sinceId) || sinceId < 0) {
        return res.status(400).json({
          code: 'invalid_since_id',
          message: 'since parameter must be a non-negative integer',
        });
      }

      const events = await service.listEvents({
        organizationId: req.auth.organizationId,
        sinceId,
      });

      res.status(200).json({ events });
    } catch (err) {
      next(err);
    }
  });

  router.get('/sync/stream', requireRole(...ALL_ROLES), async (req, res, next) => {
    const organizationId = req.auth.organizationId;

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    res.flushHeaders();

    res.write('event: connected\ndata: {"status":"ok"}\n\n');

    const channel = supabaseAdmin
      .channel(`sync_stream:${organizationId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'sync_events',
        },
        (payload) => {
          if (payload.new && payload.new.organization_id === organizationId) {
            res.write(`data: ${JSON.stringify({
              id: payload.new.id,
              table_name: payload.new.table_name,
              record_id: payload.new.record_id,
              action: payload.new.action,
              payload: payload.new.payload,
              created_at: payload.new.created_at,
            })}\n\n`);
          }
        }
      )
      .subscribe((status) => {
        if (status === 'SUBSCRIBED') {
          res.write('event: subscribed\ndata: {"status":"subscribed"}\n\n');
        }
      });

    const keepAlive = setInterval(() => {
      res.write(': keep-alive\n\n');
    }, 15000);

    req.on('close', () => {
      clearInterval(keepAlive);
      supabaseAdmin.removeChannel(channel);
    });
  });

  return router;
}
