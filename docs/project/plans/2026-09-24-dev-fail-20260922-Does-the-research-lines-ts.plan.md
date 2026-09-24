<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-24 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence job that runs a daily health-check summary
  Verification: `bash -n cadence/health-check.sh`

- [ ] Create a verification script that confirms the cadence job output
  Verification: `python3 scripts/verify_cadence_output.py`

- [ ] Add a test for the health-check cadence job
  Verification: `make test`

- [ ] Update dashboard to display cadence health-check results
  Verification: `bash -n dashboard/cadence-view.sh`

- [ ] Add a digest entry for cadence health-check completion
  Verification: `grep -q "cadence" digest/cadence.log`

- [ ] Verify all new scripts pass syntax checks
  Verification: `bash -n jobs/cadence/health-check.sh && bash -n scripts/verify_cadence_output.py`

This plan implements the cadence-automation research line by introducing a daily health-check job with verification, dashboard integration, and digest logging — all as normal-risk, independently verifiable steps gated by `make test`.
