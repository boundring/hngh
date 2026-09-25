<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-25 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence helper that validates job manifest syntax before execution
  Verification: bash -n cadence/validate-manifest.sh

- [ ] Create a test script that runs the manifest validator against a sample job file
  Verification: python3 tests/test-manifest-validator.py

- [ ] Add a dashboard digest entry that reports validator pass/fail status
  Verification: bash cadence/run-validator.sh && grep -q "PASS" dashboard/digest-validator.log

- [ ] Update the main Makefile test target to include the new validator check
  Verification: make test && echo "test suite passed"

- [ ] Add a lib utility function for safe path resolution used by cadence scripts
  Verification: bash -n lib/path-utils.sh && python3 -c "import sys; sys.path.insert(0, 'lib'); import path_utils; print('import ok')"

- [ ] Write integration test that exercises the full validator pipeline end-to-end
  Verification: bash tests/integration-test-validator.sh
