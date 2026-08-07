import { HttpError } from '../shared/httpError.js';

const requestsMap = new Map();
const DEFAULT_WINDOW_MS = 60 * 1000; // 1 minute window

/**
 * Rate Limiting Middleware for sensitive API endpoints (OWASP API4 protection).
 *
 * @param {Object} options
 * @param {number} [options.maxRequests=60] - Max requests per window
 * @param {number} [options.windowMs=60000] - Window duration in ms
 */
export function createRateLimiter({ maxRequests = 60, windowMs = DEFAULT_WINDOW_MS } = {}) {
  return function rateLimiterMiddleware(req, res, next) {
    const key = req.auth?.userId || req.ip || 'anonymous';
    const now = Date.now();

    let record = requestsMap.get(key);
    if (!record || now - record.startTime > windowMs) {
      record = { count: 1, startTime: now };
    } else {
      record.count += 1;
    }

    requestsMap.set(key, record);

    if (record.count > maxRequests) {
      next(HttpError.tooManyRequests('rate_limit_exceeded', 'Too many requests, please try again later'));
      return;
    }

    next();
  };
}
