<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-24 - dev-patrol-20260922-research-ledger-harvest- (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new job script that validates automation config syntax before execution
  Verification: `bash -n jobs/validate-config.sh`

- [ ] Create a test suite entry point for the new validation job
  Verification: `bash <script>`

- [ ] Update the cadence runner to invoke the new validation step before job dispatch
  Verification: `grep -q "validate-config" cadence/runner.sh`

- [ ] Add a dashboard summary line that reports validation pass/fail status
  Verification: `grep -q "validation" dashboard/summary.sh`

- [ ] Run the full test suite to confirm no regressions
  Verification: `make test`
