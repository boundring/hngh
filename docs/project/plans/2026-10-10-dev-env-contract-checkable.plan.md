<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-10 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new cadence job that runs a lint check on lib/ on every push
  Verification: `grep -q 'lint' cadence/jobs.yaml && grep -q 'lib' cadence/jobs.yaml`

- [ ] Create a verification script that confirms the lint job is registered in the cadence manifest
  Verification: `bash -n cadence/jobs.yaml && python3 -c "import yaml; yaml.safe_load(open('cadence/jobs.yaml'))"`

- [ ] Add a test case in tests/ that asserts the lint job output is captured on successful runs
  Verification: `bash -n tests/test_lint_job.sh && grep -q 'lint' tests/test_lint_job.sh`

- [ ] Update the dashboard to display the lint job status alongside existing cadence entries
  Verification: `grep -q 'lint' dashboard/status.html && grep -q 'cadence' dashboard/status.html`

- [ ] Run the full test suite to confirm all new steps pass without breaking existing automation
  Verification: `make test`
