<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-15 - dev-fail-20260914-Does-the-backend-log-show- (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the instrumentation and verification gaps identified across the adopted research lines by adding machine-checkable staleness detection for the crumb writer, enforcing idempotency keys for mark-read persistence, and establishing a canonical diff check for the patrol verdict rule to prevent drift.

## Steps

- [ ] Add an idempotency key generation step to the mark-read client script in scripts/
  Verification: grep -q "idempotency" scripts/mark-read.sh && bash -n scripts/mark-read.sh
- [ ] Create a crumb writer staleness checker script that compares last-run timestamp against threshold
  Verification: bash -n scripts/check-crumb-staleness.sh && make test
- [ ] Add a CI verification step that diffs the embedded patrol verdict rule against the canonical kernel rules file
  Verification: grep -q "verdict-rule" .github/workflows/ci.yml && make test
- [ ] Update the dashboard digest to include crumb writer last-run timestamp and failure state fields
  Verification: grep -q "last_run_timestamp" dashboard/digest-template.md && make test
- [ ] Add a test fixture that simulates a mark-read response with missing idempotency key to verify client-side error handling
  Verification: python3 tests/test_mark_read_idempotency.py && make test
