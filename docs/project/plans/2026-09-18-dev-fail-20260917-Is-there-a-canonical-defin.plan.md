<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-18 - dev-fail-20260917-Is-there-a-canonical-defin (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the cadence-observability research line by adding a small local status surface for hngh-automation without changing runtime configuration.
It keeps each step independently checkable and gated by ordinary repository tests.

## Steps

- [ ] Add cadence/status.sh that scans jobs/*.yml and prints candidate job names for the next cadence pass.
  Verification: bash -n cadence/status.sh
- [ ] Add lib/cadence_status.py with stdlib-only helpers to parse job due dates, runnable as a self-test.
  Verification: python3 lib/cadence_status.py
- [ ] Add tests/test_cadence_status.py that exercises lib/cadence_status.py against fixture strings and exits nonzero on failure.
  Verification: python3 tests/test_cadence_status.py
- [ ] Add dashboard/cadence.html as a static local page with a cadence status table placeholder and no network calls.
  Verification: grep -q "cadence" dashboard/cadence.html
- [ ] Add digest/cadence.md with a short Cadence section summarizing the new status surface.
  Verification: grep -q "Cadence" digest/cadence.md
