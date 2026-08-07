BEGIN;
SELECT plan(4);

-- Behavior 1 (issue 030): weekly recurrence (interval=1) on Mondays,
-- anchored on a Monday, within an 8-week window returns exactly the 8
-- Mondays in that window — pure function, no fixtures needed.
SELECT is(
  (SELECT array_agg(d ORDER BY d) FROM private.onda5_series_occurrence_dates(
    '2026-09-07'::date,      -- anchor_date (a Monday)
    array[1]::smallint[],    -- recurrence_days: Monday only
    1::smallint,             -- recurrence_interval_weeks
    '2026-09-07'::date,      -- valid_from
    null::date,              -- valid_until (open-ended)
    '2026-09-07'::date,      -- window_start
    '2026-11-01'::date       -- window_end (anchor + 55 days = 8 full weeks [0,56), inclusive bound)
  ) AS d),
  array['2026-09-07', '2026-09-14', '2026-09-21', '2026-09-28', '2026-10-05', '2026-10-12', '2026-10-19', '2026-10-26']::date[],
  'weekly Monday recurrence over an 8-week window returns exactly the 8 Mondays'
);

-- Behavior 2 (issue 030): recurrence_interval_weeks = 2 (biweekly) only
-- materializes every OTHER Monday relative to the anchor's own week.
SELECT is(
  (SELECT array_agg(d ORDER BY d) FROM private.onda5_series_occurrence_dates(
    '2026-09-07'::date, array[1]::smallint[], 2::smallint,
    '2026-09-07'::date, null::date, '2026-09-07'::date, '2026-11-01'::date
  ) AS d),
  array['2026-09-07', '2026-09-21', '2026-10-05', '2026-10-19']::date[],
  'biweekly Monday recurrence skips every other Monday relative to the anchor week'
);

-- Behavior 3 (issue 030): valid_until cuts the window short even when the
-- requested window_end extends further — series-level end date always wins.
SELECT is(
  (SELECT array_agg(d ORDER BY d) FROM private.onda5_series_occurrence_dates(
    '2026-09-07'::date, array[1]::smallint[], 1::smallint,
    '2026-09-07'::date, '2026-09-22'::date, '2026-09-07'::date, '2026-11-01'::date
  ) AS d),
  array['2026-09-07', '2026-09-14', '2026-09-21']::date[],
  'valid_until truncates occurrences even when the window extends further'
);

-- Behavior 4 (issue 030): a window_start after anchor_date (simulating
-- appointment_series_extend_window reprocessing only the unmaterialized
-- tail) never re-returns already-covered dates — idempotent by
-- construction, not by a dedup step downstream.
SELECT is(
  (SELECT array_agg(d ORDER BY d) FROM private.onda5_series_occurrence_dates(
    '2026-09-07'::date, array[1]::smallint[], 1::smallint,
    '2026-09-07'::date, null::date, '2026-10-01'::date, '2026-11-01'::date
  ) AS d),
  array['2026-10-05', '2026-10-12', '2026-10-19', '2026-10-26']::date[],
  'window_start mid-series only returns dates from that point forward, never re-emitting the past'
);

SELECT * FROM finish();
ROLLBACK;
