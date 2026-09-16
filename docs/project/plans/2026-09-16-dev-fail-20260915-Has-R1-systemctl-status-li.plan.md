<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-16 - dev-fail-20260915-Has-R1-systemctl-status-li (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the research line on duplicated-and-diverged dashboard behaviors by adding a contract test that pins the shared scroll behavior logic to prevent silent divergence between copies.

## Steps

- [ ] Create `tests/test_scroll_contract.py` with a stdlib-only Python script that imports the shared scroll logic module and asserts its core state-transition function returns the expected value for a known input.
  Verification: python3 tests/test_scroll_contract.py
- [ ] Add a `scripts/check-scroll-drift.sh` bash script that greps the dashboard source files for the duplicated scroll handler identifier and fails if more than one distinct implementation signature is found.
  Verification: bash -n scripts/check-scroll-drift.sh
- [ ] Update `jobs/verify-dashboard-contracts.sh` to invoke the new drift-check script and exit non-zero if any divergence is detected, ensuring CI gates on this check.
  Verification: bash -n jobs/verify-dashboard-contracts.sh
- [ ] Add a unit test case in `tests/test_scroll_contract.py` that verifies the scroll state persistence logic correctly serializes and deserializes tab-state without data loss across two round-trips.
  Verification: python3 tests/test_scroll_contract.py
- [ ] Create `dashboard/scroll-contract.md` documenting the single-source-of-truth requirement for scroll behavior, listing the canonical module path and forbidding inline duplicates.
  Verification: grep -q "single-source" dashboard/scroll-contract.md
