<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-24 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a configuration validation script under scripts/ that checks YAML files for syntax errors
  Verification: bash -n scripts/validate_config.sh
- [ ] Create a test helper under tests/ that runs the validation script and reports pass/fail
  Verification: bash tests/test_validate.sh
- [ ] Update the main Makefile to include the new validation step in the test target
  Verification: make test
- [ ] Add a README note under cadence/ documenting the new validation workflow
  Verification: grep -q "validation" cadence/README.md
