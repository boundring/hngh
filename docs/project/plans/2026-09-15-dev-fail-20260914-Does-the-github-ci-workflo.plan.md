<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-15 - dev-fail-20260914-Does-the-github-ci-workflo (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line investigating whether the GitHub CI workflow definition contains an embedded copy of the patrol verdict rule and lacks a diff against the kernel's canonical rules file, addressing the drift between surfaces.

## Steps

- [ ] Create `scripts/check-verdict-rule-drift.sh` that extracts the verdict rule from the CI workflow surface and compares it against the canonical source path using `diff`.
  Verification: bash -n scripts/check-verdict-rule-drift.sh
- [ ] Add a step to `.github/workflows/ci.yml` that executes `scripts/check_verdict_rule_drift.sh` before the test suite.
  Verification: grep -q "check_verdict_rule_drift" .github/workflows/ci.yml
- [ ] Implement the comparison logic in `scripts/check-verdict-rule-drift.sh` to exit non-zero if the embedded rule differs from the canonical file.
  Verification: make test
- [ ] Create `tests/test_verdict_rule_drift.sh` that mocks a drifted state and asserts the check script fails correctly.
  Verification: bash tests/test_verdict_rule_drift.sh
