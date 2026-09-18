<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z -->
# 2026-09-15 - dev-fail-20260914-Does-the-backend-log-show- (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the research line `fail-20260914-Does-the-github-ci-workflow-definition-c` by adding a CI verification step that diffs the embedded patrol verdict rule against the kernel's canonical rules file to prevent drift.

## Steps

- [ ] Create `scripts/verify-verdict-rule.sh` containing logic to extract the embedded verdict rule from the CI workflow and diff it against the canonical source path.
  Verification: bash -n scripts/verify-verdict-rule.sh
- [ ] Add a step in `.github/workflows/ci.yml` that executes `scripts/verify-verdict-rule.sh` before the test suite runs.
  Verification: grep -q "verify-verdict-rule.sh" .github/workflows/ci.yml
- [ ] Create `tests/test_verdict_rule_drift.py` to assert that the diff command returns zero differences when rules are in sync.
  Verification: python3 tests/test_verdict_rule_drift.py
- [ ] Update `Makefile` to include a `test-verdict` target that runs the new verification script and test file.
  Verification: make test
