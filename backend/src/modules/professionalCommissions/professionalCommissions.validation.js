import { HttpError } from '../../shared/httpError.js';
import {
  assertKnownFields,
  validateCommissionType,
  validateCommissionValue,
  validateId,
  validateUuidField,
} from '../../shared/validation.js';

const CREATE_FIELDS = new Set(['professional_id', 'service_id', 'commission_type', 'commission_value']);
const UPDATE_FIELDS = new Set(['commission_type', 'commission_value']);

export const validateProfessionalServiceCommissionId = validateId;

export function validateCreateProfessionalServiceCommissionPayload(body) {
  assertKnownFields(body, CREATE_FIELDS);
  const professional_id = validateUuidField(body.professional_id, 'professional_id');
  const service_id = validateUuidField(body.service_id, 'service_id');
  const commission_type = validateCommissionType(body.commission_type);
  const commission_value = validateCommissionValue(body.commission_value, commission_type);
  return { professional_id, service_id, commission_type, commission_value };
}

// professional_id/service_id are the override's identity — changing them
// is deleting one override and creating another, not a patch. Only the
// commission itself (type+value, always together) can be updated.
export function validateUpdateProfessionalServiceCommissionPayload(body) {
  assertKnownFields(body, UPDATE_FIELDS);
  if (body.commission_type === undefined && body.commission_value === undefined) {
    throw HttpError.badRequest('empty_payload', 'at least one field must be provided');
  }
  if ((body.commission_type === undefined) !== (body.commission_value === undefined)) {
    throw HttpError.badRequest(
      'invalid_commission',
      'commission_type and commission_value must be provided together',
    );
  }
  const commission_type = validateCommissionType(body.commission_type);
  const commission_value = validateCommissionValue(body.commission_value, commission_type);
  return { commission_type, commission_value };
}
