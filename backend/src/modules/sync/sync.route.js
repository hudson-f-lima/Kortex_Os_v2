import { Router } from 'express';
import { requireRole } from '../../middleware/requireRole.js';
import { createSyncService } from './sync.service.js';

const ALL_ROLES = ['owner', 'admin', 'manager', 'reception', 'professional'];

export function syncRouter({ supabaseAdmin, organizationContext }) {
  const router = Router();
  const service = createSyncService(supabaseAdmin);

  // supabaseAdmin.channel(topic) reuses an existing RealtimeChannel instance
  // when one with the same topic is already subscribed (see @supabase/realtime-js
  // RealtimeClient#channel). Concurrent SSE requests for the same organization
  // would otherwise call `.on()` again on an already-subscribed channel, which
  // throws synchronously and crashes the process. This registry ensures the
  // underlying channel is created/subscribed once per organization and shared.
  const orgChannels = new Map();

  function getOrCreateOrgChannel(organizationId) {
    const existing = orgChannels.get(organizationId);
    if (existing) return existing;

    const listeners = new Set();
    const entry = { listeners, subscribed: false };

    entry.channel = supabaseAdmin
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
            for (const listener of listeners) {
              listener({ type: 'event', payload: payload.new });
            }
          }
        }
      )
      .subscribe((status) => {
        if (status === 'SUBSCRIBED') {
          entry.subscribed = true;
          for (const listener of listeners) {
            listener({ type: 'subscribed' });
          }
        }
      });

    orgChannels.set(organizationId, entry);
    return entry;
  }

  function releaseOrgChannel(organizationId, listener) {
    const entry = orgChannels.get(organizationId);
    if (!entry) return;

    entry.listeners.delete(listener);
    if (entry.listeners.size === 0) {
      orgChannels.delete(organizationId);
      supabaseAdmin.removeChannel(entry.channel);
    }
  }

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

    const listener = (message) => {
      if (message.type === 'subscribed') {
        res.write('event: subscribed\ndata: {"status":"subscribed"}\n\n');
        return;
      }

      const payload = message.payload;
      res.write(`data: ${JSON.stringify({
        id: payload.id,
        table_name: payload.table_name,
        record_id: payload.record_id,
        action: payload.action,
        payload: payload.payload,
        created_at: payload.created_at,
      })}\n\n`);
    };

    const entry = getOrCreateOrgChannel(organizationId);
    entry.listeners.add(listener);
    if (entry.subscribed) {
      listener({ type: 'subscribed' });
    }

    const keepAlive = setInterval(() => {
      res.write(': keep-alive\n\n');
    }, 15000);

    req.on('close', () => {
      clearInterval(keepAlive);
      releaseOrgChannel(organizationId, listener);
    });
  });

  return router;
}
