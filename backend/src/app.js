import express from 'express';
import cors from 'cors';
import { requestId } from './middleware/requestId.js';
import { createAuthMiddleware } from './middleware/auth.js';
import { createOrganizationContextMiddleware } from './middleware/organizationContext.js';
import { errorHandler } from './middleware/errorHandler.js';
import { HttpError } from './shared/httpError.js';
import { healthRouter } from './modules/health/health.route.js';
import { organizationsRouter } from './modules/organizations/organizations.route.js';
import { clientsRouter } from './modules/clients/clients.route.js';
import { professionalsRouter } from './modules/professionals/professionals.route.js';
import { servicesRouter } from './modules/services/services.route.js';
import { productsRouter } from './modules/products/products.route.js';
import { catalogRouter } from './modules/catalog/catalog.route.js';
import { appointmentsRouter } from './modules/appointments/appointments.route.js';

export function createApp(env, supabaseAdmin) {
  const app = express();

  app.use(requestId);
  app.use(express.json({ limit: '1mb' }));
  app.use(
    cors({
      origin(origin, callback) {
        // Exact-match allowlist only; never substring-match a hostname.
        if (!origin || env.corsOrigins.includes(origin)) {
          callback(null, true);
          return;
        }
        callback(new Error('origin not allowed'));
      },
    }),
  );

  app.use(healthRouter());

  const auth = createAuthMiddleware(env);
  const organizationContext = createOrganizationContextMiddleware(supabaseAdmin);

  const apiRouter = express.Router();
  apiRouter.use(auth);
  apiRouter.use(organizationsRouter({ supabaseAdmin, organizationContext }));
  apiRouter.use(clientsRouter({ supabaseAdmin, organizationContext }));
  apiRouter.use(professionalsRouter({ supabaseAdmin, organizationContext }));
  apiRouter.use(servicesRouter({ supabaseAdmin, organizationContext }));
  apiRouter.use(productsRouter({ supabaseAdmin, organizationContext }));
  apiRouter.use(catalogRouter({ supabaseAdmin, organizationContext }));
  apiRouter.use(appointmentsRouter({ supabaseAdmin, organizationContext }));
  app.use('/api/v1', apiRouter);

  app.use((req, res, next) => {
    next(HttpError.notFound('not_found', 'resource not found'));
  });
  app.use(errorHandler);

  return app;
}
