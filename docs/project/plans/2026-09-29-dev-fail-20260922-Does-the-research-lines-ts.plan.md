<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-29 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence helper script that validates job manifest syntax before execution
  Verification: bash -n cadence/validate-manifest.sh

- [ ] Create a test that exercises the manifest validator against a sample job definition
  Verification: make test

- [ ] Add a dashboard digest entry that reports validator pass/fail status
  Verification: bash -n dashboard/digest-validator-report.sh

- [ ] Update the main automation entrypoint to invoke the validator before job dispatch
  Verification: make test

- [ ] Add a lib utility that extracts job metadata for downstream digest consumption
  Verification: python3 lib/extract-job-metadata.py
