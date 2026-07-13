import { logger } from '../shared/logger.js';

// Logs every request on completion (finish fires for normal responses and
// ones ended by errorHandler alike, so status/duration are always real).
// Never logs query/body/headers — only the validated organization_id set by
// organizationContext.js, never the raw X-Organization-Id header.
export function accessLog(req, res, next) {
  const startedAt = process.hrtime.bigint();
  res.on('finish', () => {
    const durationMs = Number(process.hrtime.bigint() - startedAt) / 1_000_000;
    logger.info('request_completed', {
      requestId: req.requestId,
      method: req.method,
      path: req.route ? req.baseUrl + req.route.path : req.path,
      status: res.statusCode,
      duration_ms: Math.round(durationMs * 100) / 100,
      organization_id: req.auth?.organizationId ?? null,
    });
  });
  next();
}
