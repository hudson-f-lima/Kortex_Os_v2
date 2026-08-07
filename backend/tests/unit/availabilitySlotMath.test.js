import { test } from 'node:test';
import assert from 'node:assert/strict';
import { intersectBlocks, subtractIntervalsMs, generateSlotStartsMs } from '../../src/modules/availability/availabilitySlotMath.js';

test('intersectBlocks returns the overlapping window of unit hours and shift hours', () => {
  const unitBlocks = [{ start: '09:00', end: '18:00' }];
  const shiftBlocks = [{ start: '13:00', end: '20:00' }];
  assert.deepEqual(intersectBlocks(unitBlocks, shiftBlocks), [{ startMinutes: 13 * 60, endMinutes: 18 * 60 }]);
});

test('intersectBlocks returns nothing when blocks do not overlap', () => {
  const unitBlocks = [{ start: '09:00', end: '12:00' }];
  const shiftBlocks = [{ start: '13:00', end: '18:00' }];
  assert.deepEqual(intersectBlocks(unitBlocks, shiftBlocks), []);
});

test('intersectBlocks handles multiple blocks per day (split shift/lunch break)', () => {
  const unitBlocks = [{ start: '09:00', end: '18:00' }];
  const shiftBlocks = [
    { start: '09:00', end: '12:00' },
    { start: '13:00', end: '18:00' },
  ];
  assert.deepEqual(intersectBlocks(unitBlocks, shiftBlocks), [
    { startMinutes: 9 * 60, endMinutes: 12 * 60 },
    { startMinutes: 13 * 60, endMinutes: 18 * 60 },
  ]);
});

test('subtractIntervalsMs removes an appointment that falls entirely inside a free interval', () => {
  const free = [{ startMs: 0, endMs: 10000 }];
  const occupied = [{ startMs: 3000, endMs: 5000 }];
  assert.deepEqual(subtractIntervalsMs(free, occupied), [
    { startMs: 0, endMs: 3000 },
    { startMs: 5000, endMs: 10000 },
  ]);
});

test('subtractIntervalsMs removes the whole interval when the occupied range covers it completely', () => {
  const free = [{ startMs: 1000, endMs: 2000 }];
  const occupied = [{ startMs: 0, endMs: 5000 }];
  assert.deepEqual(subtractIntervalsMs(free, occupied), []);
});

test('subtractIntervalsMs leaves non-overlapping intervals untouched', () => {
  const free = [{ startMs: 0, endMs: 1000 }];
  const occupied = [{ startMs: 2000, endMs: 3000 }];
  assert.deepEqual(subtractIntervalsMs(free, occupied), [{ startMs: 0, endMs: 1000 }]);
});

test('generateSlotStartsMs generates back-to-back slots that fit exactly, and stops before overflowing', () => {
  // 30-minute duration, 15-minute step, over a 1-hour window: 09:00, 09:15,
  // 09:30 fit (09:30+30=10:00 == window end); 09:45 would end at 10:15, excluded.
  const free = [{ startMs: 0, endMs: 60 * 60000 }];
  const slots = generateSlotStartsMs(free, 30 * 60000, 15 * 60000);
  assert.deepEqual(
    slots.map((s) => s.startMs / 60000),
    [0, 15, 30],
  );
});

test('generateSlotStartsMs returns nothing when the interval is shorter than the requested duration', () => {
  const free = [{ startMs: 0, endMs: 10 * 60000 }];
  const slots = generateSlotStartsMs(free, 30 * 60000, 15 * 60000);
  assert.deepEqual(slots, []);
});

test('generateSlotStartsMs rejects non-positive duration or step', () => {
  assert.throws(() => generateSlotStartsMs([{ startMs: 0, endMs: 1000 }], 0, 100), RangeError);
  assert.throws(() => generateSlotStartsMs([{ startMs: 0, endMs: 1000 }], 100, 0), RangeError);
});
