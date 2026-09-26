<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-26 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `cadence/verify-build.sh` script that runs `make test` and reports pass/fail status
  Verification: bash -n cadence/verify-build.sh && bash cadence/verify-build.sh

- [ ] Create `tests/test-cadence.sh` that asserts `make test` completes within a defined threshold
  Verification: bash -n tests/test-cadence.sh && bash tests/test-cadence.sh

- [ ] Update `lib/cadence-report.py` to emit structured output for CI consumption
  Verification: python3 -c "import ast; ast.parse(open('lib/cadence-report.py').read())" && python3 lib/cadence-report.py --dry-run

- [ ] Add `dashboard/build-status.md` with a template for tracking cadence verification results
  Verification: grep -q "build-status" dashboard/build-status.md

- [ ] Commit all changes and verify `make test` passes on the updated tree
  Verification: make test
