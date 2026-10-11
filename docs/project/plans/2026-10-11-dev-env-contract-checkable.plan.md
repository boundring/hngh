<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-11 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a shell script that validates a sample job manifest structure before execution
  Verification: bash -n jobs/validate-manifest.sh && bash jobs/validate-manifest.sh

- [ ] Create a cadence runner that logs execution timestamps to a digest file
  Verification: bash cadence/run-digest.sh && grep -q "timestamp" digest/latest.log

- [ ] Write a test that confirms the validation script rejects malformed input
  Verification: bash tests/test-validate.sh && grep -q "FAIL" tests/output.log

- [ ] Add a lib helper function for safe file existence checks used by cadence
  Verification: bash -n lib/file-checks.sh && grep -q "exists" lib/file-checks.sh

- [ ] Update the dashboard config to reference the new validation script path
  Verification: grep -q "validate-manifest" dashboard/config.yaml
