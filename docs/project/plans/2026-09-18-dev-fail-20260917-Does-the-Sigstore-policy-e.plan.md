<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-18 - dev-fail-20260917-Does-the-Sigstore-policy-e (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the adopted cadence-reliability research line by adding a minimal health-check cadence artifact and its verification surface.

## Steps

- [ ] Add cadence/healthcheck.sh that prints `hngh-automation health ok` and exits 0
  Verification: bash cadence/healthcheck.sh
- [ ] Add tests/cadence_healthcheck.sh that runs the health check and fails unless its output contains the expected status line
  Verification: bash tests/cadence_healthcheck.sh
- [ ] Add digest/health.md documenting the cadence health output contract with the phrase `cadence health`
  Verification: grep -q "cadence health" digest/health.md
