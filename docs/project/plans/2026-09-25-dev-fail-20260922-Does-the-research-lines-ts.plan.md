<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-25 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a job status summary script that aggregates completion signals from recent cadence runs
  Verification: bash scripts/summarize-status.sh && grep -q "status" scripts/summarize-status.sh

- [ ] Create a cadence lib module that exposes a single function for fetching the last run's outcome
  Verification: bash -n cadence/lib/run-outcome.sh && grep -q "fetch" cadence/lib/run-outcome.sh

- [ ] Wire the summary script to consume the cadence lib function and write output to dashboard/
  Verification: bash scripts/summarize-status.sh && ls dashboard/ && grep -q "outcome" dashboard/

- [ ] Add a test that validates the summary script produces non-empty output when cadence data exists
  Verification: bash tests/test-summary.sh && grep -q "PASS" tests/test-summary.sh

- [ ] Commit all changes as a single unit that passes the existing make test gate
  Verification: make test && git diff --cached --stat | wc -l
