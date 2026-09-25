<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-25 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence helper that validates job output schema before dispatch
  Verification: bash -n cadence/validate-output.sh

- [ ] Create a lib utility that normalizes job status strings across runners
  Verification: python3 lib/normalize-status.py

- [ ] Update dashboard to surface normalized status in the job list view
  Verification: bash -n dashboard/render-status.sh

- [ ] Add a test that exercises the status normalization on sample outputs
  Verification: make test

- [ ] Wire the cadence validator into the main dispatch loop
  Verification: bash -n cadence/dispatch-loop.sh
