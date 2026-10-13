// Pure functions (no I/O) for the Availability Resolver's slot generation
// (Blueprint Onda 4 §3.4, Rota A — Postgres resolves policy, Express
// orchestrates the loop and does this arithmetic). Kept dependency-free and
// side-effect-free so it is testable in isolation, without a database.

const HHMM_RE = /^([01][0-9]|2[0-3]):[0-5][0-9]$/;

function toMinutes(hhmm) {
  if (typeof hhmm !== 'string' || !HHMM_RE.test(hhmm)) {
    throw new TypeError(`expected HH:MM, got ${JSON.stringify(hhmm)}`);
  }
  const [hours, minutes] = hhmm.split(':').map(Number);
  return hours * 60 + minutes;
}

// Intersection of two lists of local HH:MM blocks (e.g. unit hours ∩
// professional shift). Blocks within each list are assumed already
// non-overlapping (enforced by private.valid_weekly_schedule at write time).
export function intersectBlocks(blocksA, blocksB) {
  const result = [];
  for (const a of blocksA) {
    for (const b of blocksB) {
      const start = Math.max(toMinutes(a.start), toMinutes(b.start));
      const end = Math.min(toMinutes(a.end), toMinutes(b.end));
      if (start < end) {
        result.push({ startMinutes: start, endMinutes: end });
      }
    }
  }
  return result;
}

// Subtracts occupied absolute-time intervals (epoch ms) from a list of free
// absolute-time intervals. Both inputs and the output use {startMs, endMs}.
export function subtractIntervalsMs(freeIntervals, occupiedIntervals) {
  let free = freeIntervals.map((interval) => ({ ...interval }));
  for (const occupied of occupiedIntervals) {
    const next = [];
    for (const block of free) {
      if (occupied.endMs <= block.startMs || occupied.startMs >= block.endMs) {
        next.push(block);
        continue;
      }
      if (occupied.startMs > block.startMs) {
        next.push({ startMs: block.startMs, endMs: Math.min(occupied.startMs, block.endMs) });
      }
      if (occupied.endMs < block.endMs) {
        next.push({ startMs: Math.max(occupied.endMs, block.startMs), endMs: block.endMs });
      }
    }
    free = next;
  }
  return free;
}

// Generates candidate slot starts (every stepMs) within free intervals, each
// long enough to fit durationMs without spilling past the interval's end.
export function generateSlotStartsMs(freeIntervals, durationMs, stepMs) {
  if (durationMs <= 0) throw new RangeError('durationMs must be positive');
  if (stepMs <= 0) throw new RangeError('stepMs must be positive');
  const slots = [];
  for (const interval of freeIntervals) {
    for (let start = interval.startMs; start + durationMs <= interval.endMs; start += stepMs) {
      slots.push({ startMs: start, endMs: start + durationMs });
    }
  }
  return slots;
}
