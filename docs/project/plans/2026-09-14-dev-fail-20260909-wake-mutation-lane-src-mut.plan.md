<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-14 - dev-fail-20260909-wake-mutation-lane-src-mut (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the research line on cadence beat latency by adding a timeout guard to the model invocation in `cadence/hour/33-research-beat.sh` and verifying its syntax.

## Steps

- [ ] Add a `timeout 60` wrapper around the model invocation command in `cadence/hour/33-research-beat.sh`
  Verification: grep -q "timeout 60" cadence/hour/33-research-beat.sh
- [ ] Add a `--max-tokens 2048` parameter to the model invocation arguments in `cadence/hour/33-research-beat.sh`
  Verification: grep -q -- "--max-tokens 2048" cadence/hour/33-research-beat.sh
- [ ] Run a syntax check on the modified beat script to ensure no shell errors were introduced
  Verification: bash -n cadence/hour/33-research-beat.sh
- [ ] Execute the repository test suite to confirm the changes do not break existing behavior
  Verification: make test
