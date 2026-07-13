import { HttpError } from '../shared/httpError.js';
import { logger } from '../shared/logger.js';

// eslint-disable-next-line no-unused-vars
export function errorHandler(err, req, res, next) {
  const requestId = req.requestId;

  if (err instanceof HttpError) {
    if (err.status >= 500) {
      logger.error('request_failed', { requestId, code: err.code, error: err.message });
    }
    res.status(err.status).json({
      code: err.code,
      message: err.message,
      request_id: requestId,
      ...(err.details ? { details: err.details } : {}),
    });
    return;
  }

  logger.error('unhandled_error', { requestId, error: err?.message });
  res.status(500).json({
    code: 'internal_error',
    message: 'unexpected server error',
    request_id: requestId,
  });
}
