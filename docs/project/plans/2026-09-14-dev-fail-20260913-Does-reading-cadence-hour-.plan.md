<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z -->
# 2026-09-14 - dev-fail-20260913-Does-reading-cadence-hour- (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the patrol research lines on github-ci and journal-error bad-execution guardrails by adding a run-close invariant check to verify that filed errors are claimed or waived before scoring.

## Steps

- [ ] Create `lib/patrol_invariant.py` implementing a function that accepts a list of error dicts and returns a boolean indicating if all are claimed or waived.
  Verification: python3 -c "import sys; sys.path.insert(0, 'lib'); from patrol_invariant import check_run_close; assert check_run_close([{'status': 'claimed'}, {'status': 'waived'}]) == True"

- [ ] Add `tests/test_patrol_invariant.py` with unit tests covering mixed claim states and unclaimed error scenarios.
  Verification: make test

- [ ] Update `cadence/hour/33-research-beat.sh` to source the invariant check before finalizing the beat score.
  Verification: bash -n cadence/hour/33-research-beat.sh

- [ ] Create `scripts/check_unclaimed_errors.py` that parses a JSON error log and exits non-zero if any error lacks a terminal status.
  Verification: python3 scripts/check_unclaimed_errors.py --help

- [ ] Add a test fixture `tests/fixtures/error_log_clean.json` containing only claimed and waived errors for validation.
  Verification: grep -q '"status": "claimed"' tests/fixtures/error_log_clean.json
