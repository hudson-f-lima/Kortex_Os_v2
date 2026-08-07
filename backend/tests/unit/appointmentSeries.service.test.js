import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createAppointmentSeriesService } from '../../src/modules/appointmentSeries/appointmentSeries.service.js';

function rpcMock(responses = {}) {
  const calls = [];
  return {
    calls,
    rpc(name, args) {
      calls.push({ name, args });
      return Promise.resolve(responses[name] ?? { data: { status: 'applied' }, error: null });
    },
  };
}

const command = {
  organizationId: '00000000-0000-0000-0000-000000000001',
  actorUserId: '00000000-0000-0000-0000-000000000002',
  idempotencyKey: 'series-command-0001',
  payload: { series_id: '00000000-0000-0000-0000-000000000003' },
};

test('appointment series service calls every server-owned series RPC with tenant and actor derived by the route', async () => {
  const supabase = rpcMock();
  const service = createAppointmentSeriesService(supabase);

  await service.create(command);
  await service.extend(command);
  await service.update(command);
  await service.cancel(command);
  await service.retryConflict(command);

  assert.deepEqual(supabase.calls.map((call) => call.name), [
    'appointment_series_create',
    'appointment_series_extend_window',
    'appointment_series_update',
    'appointment_series_cancel',
    'appointment_series_conflict_retry',
  ]);
  for (const call of supabase.calls) {
    assert.equal(call.args.p_organization_id, command.organizationId);
    assert.equal(call.args.p_actor_user_id, command.actorUserId);
    assert.equal(call.args.p_idempotency_key, command.idempotencyKey);
    assert.deepEqual(call.args.p_payload, command.payload);
  }
});

test('appointment series service maps a retry of a resolved conflict to the explicit domain error', async () => {
  const supabase = rpcMock({
    appointment_series_conflict_retry: {
      data: null,
      error: { code: 'P0020', message: 'series conflict is not open' },
    },
  });
  const service = createAppointmentSeriesService(supabase);

  await assert.rejects(
    () => service.retryConflict(command),
    (error) => error.status === 409 && error.code === 'series_conflict_not_open',
  );
});
