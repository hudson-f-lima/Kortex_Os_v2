import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  validateCreateProfessionalServiceCommissionPayload,
  validateProfessionalServiceCommissionId,
  validateUpdateProfessionalServiceCommissionPayload,
} from '../../src/modules/professionalCommissions/professionalCommissions.validation.js';

const PROFESSIONAL_ID = '11111111-1111-1111-1111-111111111111';
const SERVICE_ID = '22222222-2222-2222-2222-222222222222';

function throwsCode(fn, code) {
  assert.throws(fn, (err) => err.code === code);
}

test('validateProfessionalServiceCommissionId accepts a well-formed uuid', () => {
  assert.equal(validateProfessionalServiceCommissionId(PROFESSIONAL_ID), PROFESSIONAL_ID);
});

test('validateProfessionalServiceCommissionId rejects a non-uuid string', () => {
  throwsCode(() => validateProfessionalServiceCommissionId('nope'), 'invalid_id');
});

test('validateCreateProfessionalServiceCommissionPayload requires all fields', () => {
  throwsCode(() => validateCreateProfessionalServiceCommissionPayload({}), 'invalid_professional_id');
  throwsCode(
    () => validateCreateProfessionalServiceCommissionPayload({ professional_id: PROFESSIONAL_ID }),
    'invalid_service_id',
  );
  throwsCode(
    () =>
      validateCreateProfessionalServiceCommissionPayload({
        professional_id: PROFESSIONAL_ID,
        service_id: SERVICE_ID,
      }),
    'invalid_commission_type',
  );
  throwsCode(
    () =>
      validateCreateProfessionalServiceCommissionPayload({
        professional_id: PROFESSIONAL_ID,
        service_id: SERVICE_ID,
        commission_type: 'percentage',
      }),
    'invalid_commission_value',
  );
});

test('validateCreateProfessionalServiceCommissionPayload accepts a valid payload and rejects unknown fields', () => {
  const patch = validateCreateProfessionalServiceCommissionPayload({
    professional_id: PROFESSIONAL_ID,
    service_id: SERVICE_ID,
    commission_type: 'percentage',
    commission_value: 6000,
  });
  assert.deepEqual(patch, {
    professional_id: PROFESSIONAL_ID,
    service_id: SERVICE_ID,
    commission_type: 'percentage',
    commission_value: 6000,
  });

  throwsCode(
    () =>
      validateCreateProfessionalServiceCommissionPayload({
        professional_id: PROFESSIONAL_ID,
        service_id: SERVICE_ID,
        commission_type: 'percentage',
        commission_value: 6000,
        active: true,
      }),
    'unknown_fields',
  );
});

test('validateCreateProfessionalServiceCommissionPayload caps a percentage above 10000 basis points', () => {
  throwsCode(
    () =>
      validateCreateProfessionalServiceCommissionPayload({
        professional_id: PROFESSIONAL_ID,
        service_id: SERVICE_ID,
        commission_type: 'percentage',
        commission_value: 10001,
      }),
    'invalid_commission_value',
  );
});

test('validateUpdateProfessionalServiceCommissionPayload rejects professional_id/service_id and an empty patch', () => {
  throwsCode(() => validateUpdateProfessionalServiceCommissionPayload({}), 'empty_payload');
  throwsCode(
    () => validateUpdateProfessionalServiceCommissionPayload({ professional_id: PROFESSIONAL_ID }),
    'unknown_fields',
  );
  throwsCode(
    () => validateUpdateProfessionalServiceCommissionPayload({ commission_type: 'percentage' }),
    'invalid_commission',
  );
  throwsCode(
    () => validateUpdateProfessionalServiceCommissionPayload({ commission_value: 6000 }),
    'invalid_commission',
  );
});

test('validateUpdateProfessionalServiceCommissionPayload accepts commission_type and commission_value together', () => {
  const patch = validateUpdateProfessionalServiceCommissionPayload({
    commission_type: 'fixed',
    commission_value: 1500,
  });
  assert.deepEqual(patch, { commission_type: 'fixed', commission_value: 1500 });
});
