<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-12 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new job under `jobs/` that runs an empty shell script to serve as a baseline automation target
  Verification: `bash -n jobs/hngh-automation-baseline.sh`

- [ ] Create a corresponding test script under `tests/` that invokes `make test` against the new job and asserts exit code 0
  Verification: `bash tests/hngh-automation-baseline-test.sh`

- [ ] Add a script under `scripts/` that parses the job output and confirms the baseline job completed without errors
  Verification: `bash scripts/hngh-automation-baseline-check.sh`

- [ ] Integrate the new job into the existing cadence by adding a reference in `cadence/` that points to the job path
  Verification: `grep -q "hngh-automation-baseline" cadence/*.yaml`

- [ ] Run `make test` in the repository root to confirm all existing and new tests pass
  Verification: `make test`

- [ ] Verify that no changes were made to `hngh kernel src/tests/Makefile/hngh.asd` or any credential or systemd files
  Verification: `git diff --name-only | grep -E "(hngh\.asd|systemd|credential|secret)" || echo "No forbidden files modified"`
