<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z -->
# 2026-09-16 - dev-fail-20260915-If-drift-is-confirmed-in-t (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the research line "If drift is confirmed in the scroll behavior, which other nominally-shared dashboard behaviors exhibit the same duplicated-and-diverged pattern?" by establishing a contract test for shared verdict rules to prevent silent divergence between kernel and automation surfaces.

## Steps

- [ ] Create `tests/test_verdict_rule_parity.py` that imports the canonical verdict logic from the kernel repo path and asserts its output matches the embedded copy in `lib/verdict.py`
  Verification: python3 tests/test_verdict_rule_parity.py

- [ ] Add a regression fixture to `tests/fixtures/verdict_drift_baseline.json` containing three known input/output pairs that pin the shared contract against silent drift
  Verification: grep -q "total-vm" tests/fixtures/verdict_drift_baseline.json

- [ ] Extend `lib/verdict.py` to expose a `verify_parity()` function that compares kernel-side and automation-side verdict results for identical inputs
  Verification: python3 -c "from lib.verdict import verify_parity; print(verify_parity.__doc__ is not None)"

- [ ] Add a CI gate step in `scripts/ci_verdict_check.sh` that runs the parity test and fails if any divergence is detected
  Verification: bash -n scripts/ci_verdict_check.sh

- [ ] Update `tests/test_dashboard_shared_behaviors.py` to assert that tab-state persistence and cost display modules import from the same shared verdict source rather than duplicating logic
  Verification: make test
