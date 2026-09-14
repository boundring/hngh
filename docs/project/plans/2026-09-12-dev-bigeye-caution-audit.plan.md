<!-- plan: status=accepted risk=normal accepted=2026-09-12T18:32:23Z -->
# 2026-09-12 - dev-bigeye-caution-audit (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the gdelt-gkg-trends research line by adding a multi-window NumSources aggregation signal to the morning paper's story selection logic.

## Steps

- [x] Add a `num_sources_window` function to `lib/gdelt.py` that accepts a list of timestamps and a window size in hours, returning the count of unique sources within that window.
  Verification: python3 -c "import sys; sys.path.insert(0,'.'); from lib.gdelt import num_sources_window; print(num_sources_window([1,2,3], 1))"

- [x] Create `scripts/gdelt_num_sources.py` that imports the new function and prints a sample aggregation result for a hardcoded list of timestamps.
  Verification: python3 scripts/gdelt_num_sources.py

- [x] Add a test case to `tests/test_gdelt.py` that asserts `num_sources_window` correctly filters timestamps outside the specified window boundary.
  Verification: make test

- [x] Update `dashboard/morning_paper.py` to call `num_sources_window` with a 24-hour window and include the result in the story selection metadata dictionary.
  Verification: python3 -c "import sys; sys.path.insert(0,'.'); import dashboard.morning_paper"

## Execution note (2026-09-14)

Landed in hngh-automation against the real gdelt surface — the plan's
paths were synthesized guesses; four adaptations, each pinned by where
the code actually lives:

1. `lib/gdelt.py` -> `jobs/gdelt-news.py` (the lane module; no
   `lib/gdelt.py` exists). `num_sources_window(records, window_hours,
   now=None)` sums NumSources over a trailing window; bare timestamps
   count one source; malformed records fail closed (skipped).
   `rank_rows` now retains `num_sources` per item (parsed before, then
   dropped).
2. `scripts/gdelt_num_sources.py` not committed: the sample print is
   the step's own verification, nothing consumes a hardcoded-print
   script — run once instead (`num_sources_window([1,2,3], 1)` -> 3;
   24h window drops a 25h-old record, 48h keeps it).
3. `tests/test_gdelt.py` -> `tests/test-gdelt-news.py` (the lane's
   existing hermetic test file, wired into `make test`): window-boundary
   filtering, scalar form, malformed fail-closed, snapshot-history
   aggregation, stale-record exclusion, rank_rows retention. Failing
   first, then 9/9 green.
4. `dashboard/morning_paper.py` -> gdelt lane `main()`: the story
   selection point is the hourly lane (the paper consumes its digest
   block; no `dashboard/morning_paper.py` exists). `story_history()`
   reads the day's snapshots (headers already carry date + HHMM window),
   `attach_ns24()` writes the trailing-24h aggregate into each fresh
   item's metadata (`ns24`) before pick/render, so picked items carry it
   into the evidence snapshot. 24h absolute = maturity floor per the
   crystallized record; re-ranking was not in scope.

`make test` gate result recorded in the landing handoff row.
