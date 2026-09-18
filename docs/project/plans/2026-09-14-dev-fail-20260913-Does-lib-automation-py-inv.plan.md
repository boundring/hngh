<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z -->
# 2026-09-14 - dev-fail-20260913-Does-lib-automation-py-inv (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the research line `fail-20260913-Does-lib-automation-py-invoke-bin-hngh-v` by resolving the open question of whether `lib/automation.py` invokes `bin/hngh` via `subprocess` or direct import, and establishing a synchronous CI gate for the boundary as identified in the "Hngh Test Boundary" concept.

## Steps

- [ ] Create `tests/test_automation_invocation.py` to assert that `lib/automation.py` uses `subprocess` for invoking `bin/hngh` rather than direct module imports.
  Verification: python3 tests/test_automation_invocation.py
- [ ] Add a guardrail check in `lib/automation.py` to validate the post-2026-08-25 CLI contract before executing the subprocess call.
  Verification: make test
- [ ] Create `scripts/check_boundary.sh` to verify that the overnight harness is configured as a blocking pre-merge gate rather than a deferred schedule.
  Verification: bash -n scripts/check_boundary.sh
- [ ] Update `cadence/hour/33-research-beat.sh` to instrument the model leg separately from the local mechanical portion to clarify latency sources.
  Verification: bash -n cadence/hour/33-research-beat.sh
