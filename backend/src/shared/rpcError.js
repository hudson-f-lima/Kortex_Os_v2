import { HttpError } from './httpError.js';
import { mapPostgresError } from './postgresError.js';

// Maps the errcodes raised by the business RPCs (checkout_close,
// inventory_adjust, create_organization, membership_set). Their messages are
// already safe, user-facing text (no SQL/stack/secrets), set deliberately in
// the migration, so they are passed through as-is.
export function mapRpcError(error) {
  if (error instanceof HttpError) return error;
  switch (error?.code) {
    case '28000':
      return HttpError.unauthorized('invalid_actor', error.message);
    case '42501':
      return HttpError.forbidden('insufficient_role', error.message);
    case '22023':
      return HttpError.badRequest('invalid_payload', error.message);
    case 'P0001':
      return HttpError.conflict('operation_rejected', error.message);
    case 'P0002':
      return HttpError.badRequest('reference_not_found', error.message);
    default:
      return mapPostgresError(error);
  }
}
