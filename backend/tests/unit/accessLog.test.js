import { test } from 'node:test';
import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { accessLog } from '../../src/middleware/accessLog.js';
import { logger } from '../../src/shared/logger.js';

function fakeRes() {
  const res = new EventEmitter();
  res.statusCode = 200;
  return res;
}

test('accessLog logs method/path/status/duration/requestId on finish', () => {
  const calls = [];
  const originalInfo = logger.info;
  logger.info = (msg, meta) => calls.push({ msg, meta });

  try {
    const req = { requestId: 'req-1', method: 'GET', path: '/health', route: null };
    const res = fakeRes();
    res.statusCode = 200;

    accessLog(req, res, () => {});
    res.emit('finish');

    assert.equal(calls.length, 1);
    assert.equal(calls[0].msg, 'request_completed');
    assert.equal(calls[0].meta.requestId, 'req-1');
    assert.equal(calls[0].meta.method, 'GET');
    assert.equal(calls[0].meta.path, '/health');
    assert.equal(calls[0].meta.status, 200);
    assert.equal(calls[0].meta.organization_id, null);
    assert.equal(typeof calls[0].meta.duration_ms, 'number');
  } finally {
    logger.info = originalInfo;
  }
});

test('accessLog reports the validated organization_id, never a raw header', () => {
  const calls = [];
  const originalInfo = logger.info;
  logger.info = (msg, meta) => calls.push({ msg, meta });

  try {
    const req = {
      requestId: 'req-2',
      method: 'POST',
      path: '/api/v1/clients',
      route: null,
      auth: { organizationId: 'org-123' },
      headers: { 'x-organization-id': 'org-attacker-supplied' },
    };
    const res = fakeRes();
    res.statusCode = 201;

    accessLog(req, res, () => {});
    res.emit('finish');

    assert.equal(calls[0].meta.organization_id, 'org-123');
  } finally {
    logger.info = originalInfo;
  }
});
