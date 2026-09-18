<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z -->
# 2026-09-14 - dev-patrol-20260914-journal-error-unclaimed- (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the `patrol-20260914-journal-error-unclaimed-err` research line by establishing a run-close invariant that ensures every journal error is claimed or waived before a patrol run is scored as clean, preventing recurring `unclaimed-err` failures.

## Steps

- [ ] Create `lib/journal_guard.py` implementing the `verify_run_close_invariant(errors: list[dict]) -> tuple[bool, str]` function that returns `(False, "unclaimed-err")` if any error lacks a terminal state (claimed/waived/closed) and includes metadata for attribution.
  Verification: python3 -c "import sys; sys.path.insert(0, 'lib'); from journal_guard import verify_run_close_invariant; assert verify_run_close_invariant([])[0] == True; assert verify_run_close_invariant([{'state': 'open'}])[1] == 'unclaimed-err'; print('ok')"

- [ ] Add `tests/test_journal_guard.py` with unit tests covering empty error lists, all-claimed scenarios, mixed states, and missing terminal state fields to validate the invariant logic.
  Verification: make test

- [ ] Create `scripts/patrol_close_check.sh` that invokes `lib/journal_guard.py` via Python, accepts a JSON file path of journal errors as argument, and exits non-zero with reason `unclaimed-err` if any error remains unclaimed.
  Verification: bash -n scripts/patrol_close_check.sh

- [ ] Add `tests/test_patrol_close_check.sh` that creates temporary JSON fixtures for clean and dirty runs, executes `scripts/patrol_close_check.sh`, and asserts exit codes match the invariant outcome.
  Verification: make test

- [ ] Update `cadence/patrol-run-close.md` to document the run-close invariant requirement, specifying that patrol scoring must call `scripts/patrol_close_check.sh` before marking a run clean and that failure reason `unclaimed-err` carries error metadata.
  Verification: grep -q "run-close invariant" cadence/patrol-run-close.md && grep -q "unclaimed-err" cadence/patrol-run-close.md
