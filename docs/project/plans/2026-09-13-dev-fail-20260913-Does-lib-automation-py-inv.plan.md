<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z -->
# 2026-09-13 - dev-fail-20260913-Does-lib-automation-py-inv (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a test case in `tests/` that verifies `lib/automation.py` does not invoke `bin/hngh` via subprocess or direct module import
  Verification: bash -n tests/test_automation_invocation_mechanism.py
- [ ] Create a script under `scripts/` to check if existing integration tests cover the `lib/automation.py` ↔ `bin/hngh` boundary
  Verification: python3 scripts/check_integration_test_coverage.py
- [ ] Ensure the guardrail bug from 2026-08-25 is resolved in the current kernel version and that `lib/automation.py` handles the corrected CLI contract without errors
  Verification: bash -n tests/test_guardrail_bug_resolution.py
- [ ] Address the latency issue in `cadence/hour/33-research-beat.sh` where wall=28.3s is observed against a 0.1s median
  Verification: python3 scripts/check_beat_latency_metrics.py
