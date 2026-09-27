<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-27 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a shell script that validates the make test target runs without errors
  Verification: bash -n jobs/test-runner.sh
- [ ] Create a verification script that confirms the test suite passes
  Verification: make test
- [ ] Add a cadence file documenting the test runner workflow
  Verification: bash -n cadence/test-runner.md
- [ ] Verify the new script is executable and has correct permissions
  Verification: bash jobs/test-runner.sh
- [ ] Confirm the test suite still passes after adding the new script
  Verification: make test

Rationale: This plan implements the research line "hngh-automation test infrastructure validation" by adding a simple, normal-risk test runner script that validates the existing make test target without touching forbidden areas like provider configuration, systemd units, or kernel source changes.
