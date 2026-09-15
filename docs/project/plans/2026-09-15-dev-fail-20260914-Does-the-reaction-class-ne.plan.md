<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-15 - dev-fail-20260914-Does-the-reaction-class-ne (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the research line fail-20260914-push-divergence-jcode-20260914 by adding a pre-push coordination guard that enforces re-fetch and rebase before pushing to prevent non-fast-forward refusals from same-host jcode sessions racing origin main.

## Steps

- [ ] Create scripts/pre-push-guard.sh implementing a check that fetches origin/main, verifies the local HEAD is a descendant of origin/main via git merge-base --is-ancestor, and exits non-zero with an actionable message if not
  Verification: bash -n scripts/pre-push-guard.sh
- [ ] Add tests/test-pre-push-guard.sh that sets up a temporary git repository fixture with diverged branches and asserts the guard script correctly detects non-fast-forward state and passes on fast-forward state
  Verification: make test
- [ ] Create jobs/push-coordination.md documenting the coordination rule requiring re-fetch/rebase before push, citing the 2026-09-14 NFF refusal as the motivating incident
  Verification: grep -q 're-fetch' jobs/push-coordination.md && grep -q 'origin/main' jobs/push-coordination.md
- [ ] Add a cadence/cadence-push-guard.sh wrapper that invokes scripts/pre-push-guard.sh and logs the outcome to digest/ with timestamp for auditability
  Verification: bash -n cadence/cadence-push-guard.sh
