import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  validateAppointmentId,
  validateAppointmentPayload,
} from '../../src/modules/appointments/appointments.validation.js';

function throwsCode(fn, code) {
  assert.throws(fn, (err) => err.code === code);
}

const UUID = '11111111-1111-1111-1111-111111111111';
const VALID_CREATE = {
  client_id: UUID,
  professional_id: UUID,
  service_id: UUID,
  starts_at: '2026-08-01T10:00:00Z',
};

test('validateAppointmentId accepts a well-formed uuid', () => {
  assert.equal(validateAppointmentId(UUID), UUID);
});

test('validateAppointmentId rejects a non-uuid string', () => {
  throwsCode(() => validateAppointmentId('nope'), 'invalid_id');
});

test('validateAppointmentPayload requires client_id, professional_id, service_id and starts_at on create', () => {
  throwsCode(() => validateAppointmentPayload({}, { requireAll: true }), 'invalid_client_id');
  throwsCode(() => validateAppointmentPayload({ client_id: UUID }, { requireAll: true }), 'invalid_professional_id');
  throwsCode(
    () => validateAppointmentPayload({ client_id: UUID, professional_id: UUID }, { requireAll: true }),
    'invalid_service_id',
  );
  throwsCode(
    () =>
      validateAppointmentPayload(
        { client_id: UUID, professional_id: UUID, service_id: UUID },
        { requireAll: true },
      ),
    'invalid_starts_at',
  );
});

test('validateAppointmentPayload accepts a valid create payload', () => {
  const patch = validateAppointmentPayload(VALID_CREATE, { requireAll: true });
  assert.equal(patch.client_id, UUID);
  assert.equal(patch.starts_at, new Date(VALID_CREATE.starts_at).toISOString());
  assert.equal(patch.ends_at, undefined, 'ends_at is never accepted from the client — it is server-computed');
  assert.equal(patch.status, undefined, 'status is optional and defaults in the database');
});

test('validateAppointmentPayload rejects a malformed starts_at', () => {
  throwsCode(
    () => validateAppointmentPayload({ ...VALID_CREATE, starts_at: 'not-a-date' }, { requireAll: true }),
    'invalid_starts_at',
  );
});

// Fase 10 hardening: ends_at is always resolved server-side from the
// service/capability duration. A client sending it gets a loud 400
// (unknown_fields) instead of the value being silently discarded.
test('validateAppointmentPayload rejects a client-supplied ends_at', () => {
  throwsCode(
    () => validateAppointmentPayload({ ...VALID_CREATE, ends_at: '2026-08-01T10:30:00Z' }, { requireAll: true }),
    'unknown_fields',
  );
});

test('validateAppointmentPayload validates status against the enum', () => {
  const patch = validateAppointmentPayload({ status: 'confirmed' }, { requireAll: false });
  assert.equal(patch.status, 'confirmed');
  throwsCode(() => validateAppointmentPayload({ status: 'bogus' }, { requireAll: false }), 'invalid_status');
});

test('validateAppointmentPayload rejects unknown fields', () => {
  throwsCode(() => validateAppointmentPayload({ ...VALID_CREATE, price_cents: 100 }, { requireAll: true }), 'unknown_fields');
});

test('validateAppointmentPayload on update allows a partial patch', () => {
  const patch = validateAppointmentPayload({ status: 'cancelled' }, { requireAll: false });
  assert.deepEqual(patch, { status: 'cancelled' });
});

test('validateAppointmentPayload rejects an empty patch on update', () => {
  throwsCode(() => validateAppointmentPayload({}, { requireAll: false }), 'empty_payload');
});
