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
  const patch = validateAppointmentPayload({ status: 'confirmed', version: 1 }, { requireAll: false });
  assert.equal(patch.status, 'confirmed');
  throwsCode(() => validateAppointmentPayload({ status: 'bogus', version: 1 }, { requireAll: false }), 'invalid_status');
});

test('validateAppointmentPayload rejects unknown fields', () => {
  throwsCode(() => validateAppointmentPayload({ ...VALID_CREATE, price_cents: 100 }, { requireAll: true }), 'unknown_fields');
});

// ADR 0012: version is mandatory on every update, not just when the client
// also changes another field — it is how the optimistic-lock RPC knows what
// the client last read.
test('validateAppointmentPayload on update allows a partial patch alongside version', () => {
  const patch = validateAppointmentPayload({ status: 'cancelled', version: 3 }, { requireAll: false });
  assert.deepEqual(patch, { status: 'cancelled', version: 3 });
});

test('validateAppointmentPayload requires version on update, even with no other field', () => {
  throwsCode(() => validateAppointmentPayload({}, { requireAll: false }), 'missing_version');
});

test('validateAppointmentPayload rejects a non-integer version', () => {
  throwsCode(() => validateAppointmentPayload({ version: 'nope' }, { requireAll: false }), 'invalid_version');
  throwsCode(() => validateAppointmentPayload({ version: 0 }, { requireAll: false }), 'invalid_version');
});

// ADR 0013: confirm is optional and only meaningful when the update also
// reconfigures professional_id/service_id, but it is accepted whenever sent.
test('validateAppointmentPayload accepts an optional confirm flag on update', () => {
  const patch = validateAppointmentPayload({ version: 1, confirm: true }, { requireAll: false });
  assert.deepEqual(patch, { version: 1, confirm: true });
  throwsCode(() => validateAppointmentPayload({ version: 1, confirm: 'yes' }, { requireAll: false }), 'invalid_confirm');
});

test('validateAppointmentPayload rejects version/confirm on create', () => {
  throwsCode(() => validateAppointmentPayload({ ...VALID_CREATE, version: 1 }, { requireAll: true }), 'unknown_fields');
  throwsCode(() => validateAppointmentPayload({ ...VALID_CREATE, confirm: true }, { requireAll: true }), 'unknown_fields');
});
