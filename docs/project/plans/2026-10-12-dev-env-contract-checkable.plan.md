<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-12 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a reusable job-output validator script under scripts/validate-job-output.sh that checks exit codes and stdout patterns
  Verification: bash -n scripts/validate-job-output.sh
- [ ] Add a test case under tests/ that exercises the validator with a sample job directory
  Verification: make test
- [ ] Add a cadence helper under cadence/run-check.sh that invokes the validator against the last job run
  Verification: bash -n cadence/run-check.sh
- [ ] Add a dashboard snippet under dashboard/job-status.json that records validator pass/fail state
  Verification: bash -n dashboard/job-status.json
- [ ] Add a lib helper under lib/job-utils.sh that wraps the validator for reuse by other scripts
  Verification: bash -n lib/job-utils.sh
- [ ] Add a test under tests/ that verifies the cadence helper integrates with the dashboard state
  Verification: make test
