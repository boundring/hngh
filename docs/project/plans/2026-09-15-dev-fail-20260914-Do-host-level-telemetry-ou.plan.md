<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z -->
# 2026-09-15 - dev-fail-20260914-Do-host-level-telemetry-ou (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the fail-20260914-push-divergence-jcode-20260914 research line by adding a pre-push synchronization guard to prevent non-fast-forward refusals caused by same-host session races.

## Steps

- [ ] Create `scripts/push-guard.sh` that fetches origin main and verifies the local HEAD is a descendant of the remote tip before allowing a push
  Verification: bash -n scripts/push-guard.sh

- [ ] Add a unit test in `tests/test_push_guard.py` that simulates a diverged branch scenario and asserts the guard script exits non-zero with a specific error message
  Verification: python3 tests/test_push_guard.py

- [ ] Integrate the push guard into the existing job workflow by editing `jobs/push.yaml` to invoke `scripts/push-guard.sh` as a pre-hook before the git push command
  Verification: grep -q "push-guard.sh" jobs/push.yaml

- [ ] Update the cadence documentation in `cadence/coordination-rules.md` to explicitly state that same-host jcode sessions must serialize pushes via the new guard script
  Verification: grep -q "serialize pushes" cadence/coordination-rules.md

- [ ] Run the full test suite to ensure no regressions were introduced by the new script and job integration
  Verification: make test
