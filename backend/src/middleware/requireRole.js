import { HttpError } from '../shared/httpError.js';

export function requireRole(...roles) {
  return function requireRoleMiddleware(req, res, next) {
    if (!req.auth?.role || !roles.includes(req.auth.role)) {
      next(HttpError.forbidden('insufficient_role', `requires one of roles: ${roles.join(', ')}`));
      return;
    }
    next();
  };
}
