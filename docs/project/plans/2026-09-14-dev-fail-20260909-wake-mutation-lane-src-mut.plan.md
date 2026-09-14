<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-14 - dev-fail-20260909-wake-mutation-lane-src-mut (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the research line on cadence beat latency by adding a timeout and max-tokens guard to the model leg of `cadence/hour/33-research-beat.sh` to close the unguarded execution defect.

## Steps

- [ ] Add a `timeout` wrapper around the model invocation in `cadence/hour/33-research-beat.sh`
  Verification: grep -q "timeout" cadence/hour/33-research-beat.sh
- [ ] Define a `MAX_TOKENS` variable and pass it to the model call in `cadence/hour/33-research-beat.sh`
  Verification: grep -q "MAX_TOKENS" cadence/hour/33-research-beat.sh
- [ ] Add a shell syntax check script for the beat to `scripts/check-syntax.sh`
  Verification: bash -n scripts/check-syntax.sh
- [ ] Create a test fixture in `tests/test-timeout-guard.sh` that mocks a slow model call
  Verification: bash -n tests/test-timeout-guard.sh
- [ ] Update the Makefile to include the new syntax check in the test target
  Verification: make test
