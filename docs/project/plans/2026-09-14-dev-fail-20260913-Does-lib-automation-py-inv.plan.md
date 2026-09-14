<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-14 - dev-fail-20260913-Does-lib-automation-py-inv (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the research line `fail-20260913-Does-lib-automation-py-invoke-bin-hngh-v` by verifying the invocation mechanism and adding a synchronous integration test for the `lib/automation.py` ↔ `bin/hngh` boundary.

## Steps

- [ ] Inspect `lib/automation.py` to confirm whether it invokes `bin/hngh` via `subprocess` or direct module import
  Verification: grep -n "subprocess\|import.*hngh" lib/automation.py
- [ ] Create a minimal integration test script under `tests/` that exercises the `lib/automation.py` ↔ `bin/hngh` boundary using a stubbed subprocess seam
  Verification: bash -n tests/test_automation_boundary.sh
- [ ] Add a make target or update existing test suite to run the new integration test as part of `make test`
  Verification: make test
- [ ] Verify that the overnight harness configuration references the corrected CLI contract post-2026-08-25 guardrail fix
  Verification: grep -n "guardrail\|cli-contract" cadence/overnight-harness.sh
- [ ] Add a latency assertion to `cadence/hour/33-research-beat.sh` that flags wall-time deviations exceeding 2x the median
  Verification: bash -n cadence/hour/33-research-beat.sh
