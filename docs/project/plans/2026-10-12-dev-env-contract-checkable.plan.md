<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-12 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implement the "Safe Cadence Dry-Run" research line by adding a no-op execution mode to the digest pipeline, ensuring pipeline changes are validated without side effects before scheduling.

## Steps

- [ ] Add `--dry-run` flag to `cadence/runner.sh` to bypass execution
  Verification: bash -n cadence/runner.sh

- [ ] Update `digest/generate.py` to skip file writes when dry-run is active
  Verification: python3 -c "import ast; ast.parse(open('digest/generate.py').read())"

- [ ] Add syntax validation script `scripts/check_syntax.sh` for pipeline files
  Verification: bash -n scripts/check_syntax.sh

- [ ] Add regression test `tests/test_dryrun.sh` covering the dry-run path
  Verification: bash -n tests/test_dryrun.sh

- [ ] Run full test suite to confirm no regressions
  Verification: make test
