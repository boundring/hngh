<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-11 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence verification script that checks job output timestamps are within expected windows
  Verification: bash -n cadence/verify-cadence.sh

- [ ] Add unit test for cadence verification script with mocked output files
  Verification: make test

- [ ] Add a digest helper that validates output file checksums against expected values
  Verification: bash -n digest/checksums.sh

- [ ] Add unit test for digest helper with sample output files
  Verification: make test

- [ ] Add a lib utility that normalizes job output paths for cross-platform consistency
  Verification: bash -n lib/normalize-paths.sh

- [ ] Add unit test for path normalization utility with edge cases
  Verification: make test
