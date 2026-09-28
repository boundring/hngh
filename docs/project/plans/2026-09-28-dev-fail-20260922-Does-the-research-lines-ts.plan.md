<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-28 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Create a new job wrapper script under jobs/ that validates input before execution
  Verification: bash -n jobs/hngh-job-wrapper.sh

- [ ] Add a test script under tests/ that exercises the new wrapper with sample inputs
  Verification: bash tests/test-hngh-job-wrapper.sh

- [ ] Update cadence configuration under cadence/ to register the new job wrapper
  Verification: grep -q "hngh-job-wrapper" cadence/cadence.yaml

- [ ] Run make test to confirm no existing tests are broken
  Verification: make test

- [ ] Add a verification script under scripts/ that checks the wrapper's exit code on invalid input
  Verification: bash scripts/verify-hngh-job-wrapper-exit.sh

- [ ] Commit all changes and verify the repository is clean
  Verification: git status --porcelain | grep -q .
