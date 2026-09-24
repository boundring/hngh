<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-24 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a helper script that validates job file syntax before execution
  Verification: bash -n scripts/job-syntax-validator.sh

- [ ] Create a test fixture that generates a minimal valid job file for regression testing
  Verification: make test

- [ ] Add a grep-based check in cadence/ that confirms no job files reference forbidden paths
  Verification: grep -r "hngh/kernel" jobs/ && echo "FAIL" || echo "PASS"

- [ ] Update the dashboard/README to document the new validation step in the pipeline
  Verification: git diff --cached dashboard/README

- [ ] Add a python3 script that parses job metadata and prints a summary for CI logging
  Verification: python3 scripts/job-metadata-summary.py

- [ ] Commit all changes and run the full test suite to confirm no regressions
  Verification: make test
