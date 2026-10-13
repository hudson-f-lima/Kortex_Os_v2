import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateSeriesCreate, validateSeriesUpdate } from '../../src/modules/appointmentSeries/appointmentSeries.validation.js';

const ids = {
  client_id: '00000000-0000-0000-0000-000000000001',
  professional_id: '00000000-0000-0000-0000-000000000002',
  service_id: '00000000-0000-0000-0000-000000000003',
  unit_id: '00000000-0000-0000-0000-000000000004',
};

test('series create contract rejects a client-supplied organization_id before any RPC call', () => {
  assert.throws(
    () => validateSeriesCreate({
      ...ids,
      organization_id: '00000000-0000-0000-0000-000000000099',
      anchor_date: '2027-03-01', local_start_time: '10:00', recurrence_days: [1], duration_minutes: 30, valid_from: '2027-03-01',
    }),
    (error) => error.status === 400 && error.code === 'unknown_fields',
  );
});

test('series update contract fails closed on an invalid scope', () => {
  assert.throws(
    () => validateSeriesUpdate({ scope: 'ALL_OCCURRENCES' }),
    (error) => error.status === 400 && error.code === 'invalid_scope',
  );
});
