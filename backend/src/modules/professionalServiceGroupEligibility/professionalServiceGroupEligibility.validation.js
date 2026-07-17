import { HttpError } from '../../shared/httpError.js';
import { assertKnownFields, validateEligibility, validateId, validateUuidField } from '../../shared/validation.js';

const CREATE_FIELDS = new Set(['professional_id', 'service_group_id', 'eligibility']);
const UPDATE_FIELDS = new Set(['eligibility']);

export const validateGroupEligibilityId = validateId;

export function validateCreateGroupEligibilityPayload(body) {
  assertKnownFields(body, CREATE_FIELDS);
  const professional_id = validateUuidField(body.professional_id, 'professional_id');
  const service_group_id = validateUuidField(body.service_group_id, 'service_group_id');
  const eligibility = body.eligibility === undefined ? 'ENABLED' : validateEligibility(body.eligibility);
  return { professional_id, service_group_id, eligibility };
}

export function validateUpdateGroupEligibilityPayload(body) {
  assertKnownFields(body, UPDATE_FIELDS);
  if (body.eligibility === undefined) {
    throw HttpError.badRequest('empty_payload', 'at least one field must be provided');
  }
  return { eligibility: validateEligibility(body.eligibility) };
}
