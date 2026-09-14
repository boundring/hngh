<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-14 - dev-patrol-20260914-journal-error-unclaimed- (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the `patrol-20260914-journal-error-unclaimed-err` research line by establishing a run-close invariant that requires all journal errors to be claimed or waived before a patrol run is scored as clean, preventing unclaimed errors from persisting across consecutive runs.

## Steps

- [ ] Add a `claim_or_waive` function to `lib/journal_error.py` that marks a filed error as either claimed (with owner) or waived (with reason), updating the error's state field in the journal record
  Verification: make test

- [ ] Create `scripts/patrol_run_close_check.py` that iterates over all errors filed during the current patrol run and exits non-zero with reason `unclaimed-err` if any error lacks a terminal state (claimed or waived)
  Verification: python3 scripts/patrol_run_close_check.py

- [ ] Add a test case to `tests/test_patrol_run_close.py` that verifies a patrol run with an unclaimed error fails the close check and a run where all errors are claimed or waived passes
  Verification: make test

- [ ] Update `jobs/patrol.py` to invoke the run-close check after scoring and before marking the run as clean, ensuring the invariant is enforced in the production path
  Verification: make test
