import { HttpError } from './httpError.js';

export function mapPostgresError(error) {
  if (error instanceof HttpError) return error;
  switch (error?.code) {
    case '23503':
      return HttpError.conflict(
        'referenced_by_other_records',
        'record is referenced by other records and cannot be deleted or changed',
      );
    case '23514':
      return HttpError.badRequest('constraint_violation', 'payload violates a database constraint');
    case '23502':
      return HttpError.badRequest('missing_required_field', 'a required field is missing');
    case '22001':
      return HttpError.badRequest('value_too_long', 'a field exceeds its maximum length');
    default:
      return error;
  }
}
