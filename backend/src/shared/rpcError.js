import { HttpError } from './httpError.js';
import { mapPostgresError } from './postgresError.js';

// Maps the errcodes raised by the business RPCs (checkout_close,
// inventory_adjust, create_organization, membership_scope_set). Their messages are
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
    case 'P0003':
      return HttpError.badRequest('professional_not_eligible_for_service', error.message);
    case 'P0004':
      return HttpError.conflict('version_conflict', error.message);
    case 'P0005':
      return HttpError.notFound('appointment_not_found', error.message);
    case 'P0006':
      return HttpError.conflict('deposit_policy_incomplete', error.message);
    case 'P0007':
      return HttpError.conflict('appointment_replan_required', error.message);
    case 'P0010':
      return HttpError.conflict('appointment_checkout_mismatch', error.message);
    case 'P0011':
      return HttpError.conflict('appointment_checkout_unit_unsupported', error.message);
    case 'P0012':
      return HttpError.conflict('deposit_hold_expired', error.message);
    case 'P0020':
      return HttpError.conflict('series_conflict_not_open', error.message);
    case 'P0021':
      return HttpError.notFound('series_conflict_not_found', error.message);
    case 'P0022':
      return HttpError.conflict('appointment_client_immutable', error.message);
    case 'P0023':
      return HttpError.conflict('waitlist_offer_not_open', error.message);
    case 'P0024':
      return HttpError.forbidden('waitlist_offer_token_mismatch', error.message);
    default:
      return mapPostgresError(error);
  }
}
