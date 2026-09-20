<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-20 - dev-fail-20260918-Does-the-path-collision-bu (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the cadence-retry-consistency research line by giving every cadence job script one shared stdlib backoff helper instead of per-script inline delay math, then pinning that helper's behavior with tests so retry delays stop drifting between jobs. The work stays normal-risk: it only adds a small library plus a shell wrapper and refactors one job script to call them, all gated by the repo's existing test gate.

## Steps

- [ ] Add lib/cadence_retry.py exposing next_delay(attempt, base=2, cap=60) that returns capped exponential backoff in seconds (stdlib only), with an `if __name__ == "__main__":` self-check block that asserts a few known values.
  Verification: python3 lib/cadence_retry.py
- [ ] Add tests/test_cadence_retry.py using unittest to assert next_delay grows per attempt and never exceeds cap for attempts 0..10, so the helper is covered by the suite.
  Verification: make test
- [ ] Add scripts/cadence_backoff.sh that reads an optional attempt argument (defaulting to a sample value) and prints the delay from the helper, giving shell callers one source of truth.
  Verification: bash scripts/cadence_backoff.sh
- [ ] Update jobs/cadence_run.sh to compute its retry delay by calling scripts/cadence_backoff.sh instead of inline arithmetic, keeping observed delays identical for attempts 0..5.
  Verification: bash -n jobs/cadence_run.sh
