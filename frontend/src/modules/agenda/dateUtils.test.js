import { describe, it, expect } from 'vitest';
import {
  addDays,
  dateKey,
  daySlots,
  dayRange,
  slotIndexForTime,
  startOfWeek,
  totalSlots,
  weekDays,
  weekRange,
} from './dateUtils.js';

describe('dateUtils', () => {
  it('startOfWeek returns the Monday of the given week', () => {
    const wednesday = new Date(2026, 6, 15); // 2026-07-15 is a Wednesday
    const monday = startOfWeek(wednesday);
    expect(monday.getDay()).toBe(1);
    expect(dateKey(monday)).toBe('2026-07-13');
  });

  it('weekDays returns 7 consecutive days starting on Monday', () => {
    const days = weekDays(new Date(2026, 6, 15));
    expect(days).toHaveLength(7);
    expect(dateKey(days[0])).toBe('2026-07-13');
    expect(dateKey(days[6])).toBe('2026-07-19');
  });

  it('dayRange spans exactly 24 hours', () => {
    const { from, to } = dayRange(new Date(2026, 6, 15, 14, 30));
    expect(new Date(to).getTime() - new Date(from).getTime()).toBe(24 * 60 * 60 * 1000);
  });

  it('weekRange spans exactly 7 days', () => {
    const { from, to } = weekRange(new Date(2026, 6, 15));
    expect(new Date(to).getTime() - new Date(from).getTime()).toBe(7 * 24 * 60 * 60 * 1000);
  });

  it('daySlots produces the expected number of 30-minute slots', () => {
    const slots = daySlots(new Date(2026, 6, 15));
    expect(slots).toHaveLength(totalSlots());
    expect(slots[0].getHours()).toBe(7);
    expect(slots[0].getMinutes()).toBe(0);
  });

  it('slotIndexForTime maps a time back to its slot index', () => {
    const day = new Date(2026, 6, 15);
    const time = new Date(2026, 6, 15, 9, 30);
    expect(slotIndexForTime(time, day)).toBe(5);
  });

  it('addDays advances the calendar day without mutating the input', () => {
    const original = new Date(2026, 6, 15);
    const next = addDays(original, 3);
    expect(dateKey(original)).toBe('2026-07-15');
    expect(dateKey(next)).toBe('2026-07-18');
  });
});
