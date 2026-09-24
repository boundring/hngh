<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-24 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new job script under jobs/ that validates automation output format
  Verification: bash -n jobs/validate-output-format.sh

- [ ] Add a corresponding test case under tests/ that exercises the new job
  Verification: make test

- [ ] Add a cadence entry under cadence/ to schedule the new job
  Verification: bash -n cadence/schedule-validate-output-format.sh

- [ ] Add a dashboard snippet under dashboard/ to display job status
  Verification: bash -n dashboard/status-display.sh

- [ ] Add a lib helper under lib/ for shared output parsing logic
  Verification: bash -n lib/output-parser.sh

- [ ] Add a digest entry under digest/ to summarize job results
  Verification: bash -n digest/summarize-validate-output-format.sh
