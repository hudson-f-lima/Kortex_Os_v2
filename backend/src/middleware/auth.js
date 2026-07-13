import { createRemoteJWKSet, jwtVerify } from 'jose';
import { HttpError } from '../shared/httpError.js';

const BEARER_PREFIX = 'Bearer ';

export function createAuthMiddleware(env) {
  const jwks = createRemoteJWKSet(new URL(env.supabaseJwksUrl));

  return async function auth(req, res, next) {
    const header = req.headers.authorization;
    if (!header || !header.startsWith(BEARER_PREFIX)) {
      next(HttpError.unauthorized('missing_bearer_token', 'Authorization: Bearer token is required'));
      return;
    }
    const token = header.slice(BEARER_PREFIX.length).trim();
    if (!token) {
      next(HttpError.unauthorized('missing_bearer_token', 'Authorization: Bearer token is required'));
      return;
    }

    try {
      const { payload } = await jwtVerify(token, jwks);
      if (payload.role !== 'authenticated' || typeof payload.sub !== 'string') {
        next(HttpError.unauthorized('invalid_token_claims', 'token does not represent an authenticated user'));
        return;
      }
      req.auth = { userId: payload.sub, email: typeof payload.email === 'string' ? payload.email : undefined };
      next();
    } catch {
      next(HttpError.unauthorized('invalid_token', 'token is missing, expired, or fails signature verification'));
    }
  };
}
