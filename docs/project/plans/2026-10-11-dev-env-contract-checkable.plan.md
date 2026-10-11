<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-11 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the research line "Structured job output validation for improved observability" by adding a lightweight shell validator and integrating it into the runner.

## Steps

- [ ] Create `scripts/validate-output.sh` that checks for a `PASS` marker in input and echoes status.
  Verification: `bash -n scripts/validate-output.sh`
- [ ] Create `tests/test-validate.sh` that asserts the validator script exists and is executable.
  Verification: `bash -n tests/test-validate.sh`
- [ ] Update `jobs/runner.sh` to invoke `scripts/validate-output.sh` after execution.
  Verification: `git grep -l validate-output.sh`
- [ ] Run `make test` to confirm integration does not break existing checks.
  Verification: `make test`
