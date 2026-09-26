<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-26 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new job script that validates a sample input payload and writes a structured result file
  Verification: bash -n jobs/sample-validation.sh && grep -q 'result' jobs/sample-validation.sh

- [ ] Create a test case that exercises the new job script with a known-good payload
  Verification: bash tests/test-sample-validation.sh && grep -q 'PASS' tests/test-sample-validation.sh

- [ ] Add a cadence entry that triggers the new job on a fixed schedule
  Verification: grep -q 'sample-validation' cadence/schedule.yaml && grep -q 'cron' cadence/schedule.yaml

- [ ] Update the dashboard digest to include a summary line for the new job
  Verification: grep -q 'sample-validation' dashboard/digest-template.md && grep -q 'summary' dashboard/digest-template.md

- [ ] Run the full test suite to confirm no regressions from the new additions
  Verification: make test && echo 'ALL_TESTS_PASS'
