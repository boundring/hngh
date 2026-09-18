<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z -->
# 2026-09-15 - dev-fail-20260914-push-divergence-jcode-2026 (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line `fail-20260914-push-divergence-jcode-20260914` by adding a pre-push synchronization check to hngh-automation that detects when local commits are not descendants of the remote tip, preventing non-fast-forward refusals caused by same-host session races.

## Steps

- [ ] Create `scripts/push-guard.sh` that runs `git fetch origin main` and exits 1 if `git merge-base --is-ancestor origin/main HEAD` fails
  Verification: bash -n scripts/push-guard.sh
- [ ] Add a test fixture in `tests/test-push-guard.sh` that simulates a diverged branch and asserts the guard script returns non-zero
  Verification: bash tests/test-push-guard.sh
- [ ] Wire the guard into the existing job pipeline by appending a call to `scripts/push-guard.sh` in `jobs/push.sh` before the final `git push` invocation
  Verification: grep -q "push-guard" jobs/push.sh
- [ ] Add a unit test case in `tests/test-push-job.sh` that mocks a diverged remote and verifies the job aborts without invoking `git push --force`
  Verification: make test
