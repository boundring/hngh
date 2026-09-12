<!-- plan: status=accepted risk=normal accepted=2026-09-12T18:32:23Z -->
# 2026-09-12 - dev-bigeye-caution-audit (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the gdelt-gkg-trends research line by adding a multi-window NumSources aggregation signal to the morning paper's story selection logic.

## Steps

- [ ] Add a `num_sources_window` function to `lib/gdelt.py` that accepts a list of timestamps and a window size in hours, returning the count of unique sources within that window.
  Verification: python3 -c "import sys; sys.path.insert(0,'.'); from lib.gdelt import num_sources_window; print(num_sources_window([1,2,3], 1))"

- [ ] Create `scripts/gdelt_num_sources.py` that imports the new function and prints a sample aggregation result for a hardcoded list of timestamps.
  Verification: python3 scripts/gdelt_num_sources.py

- [ ] Add a test case to `tests/test_gdelt.py` that asserts `num_sources_window` correctly filters timestamps outside the specified window boundary.
  Verification: make test

- [ ] Update `dashboard/morning_paper.py` to call `num_sources_window` with a 24-hour window and include the result in the story selection metadata dictionary.
  Verification: python3 -c "import sys; sys.path.insert(0,'.'); import dashboard.morning_paper"
