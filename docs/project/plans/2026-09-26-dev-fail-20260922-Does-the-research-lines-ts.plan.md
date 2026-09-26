<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-26 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new cadence job that runs `make test` on a single automation module
  Verification: `grep -q 'make test' cadence/jobs/*`

- [ ] Create a verification script that confirms the job output contains "PASS"
  Verification: `bash -n scripts/verify-cadence-output.sh`

- [ ] Add a test case that exercises the new cadence job path
  Verification: `bash tests/test-cadence-job.sh`

- [ ] Update the dashboard to display the new job's status
  Verification: `grep -q 'new-job' dashboard/*.html`

- [ ] Run the full test suite to confirm no regressions
  Verification: `make test`

- [ ] Verify all new files pass syntax checks
  Verification: `bash -n scripts/verify-cadence-output.sh && node --check dashboard/*.js`
