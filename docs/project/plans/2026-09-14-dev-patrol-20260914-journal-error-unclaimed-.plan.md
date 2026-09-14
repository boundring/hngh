<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-14 - dev-patrol-20260914-journal-error-unclaimed- (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the patrol-20260914-journal-error-unclaimed-err research line by adding a run-close invariant that requires every filed journal error to be claimed or waived before a patrol run is scored clean, preventing unclaimed errors from resurfacing on consecutive runs.

## Steps

- [ ] Add a `claim_or_waive` function to `lib/journal_error.py` that marks a filed error as claimed or waived and returns the updated state
  Verification: python3 -c "import lib.journal_error; assert hasattr(lib.journal_error, 'claim_or_waive')"

- [ ] Update `jobs/patrol_run.py` to invoke `claim_or_waive` for each filed journal error before scoring and fail with reason `unclaimed-err` if any remain unclaimed
  Verification: grep -q "unclaimed-err" jobs/patrol_run.py

- [ ] Add a test case in `tests/test_patrol_unclaimed_err.py` that simulates a run with an unclaimed error and asserts the run fails with reason `unclaimed-err`
  Verification: make test

- [ ] Add a test case in `tests/test_patrol_unclaimed_err.py` that simulates a run where all errors are claimed or waived and asserts the run scores clean
  Verification: make test
