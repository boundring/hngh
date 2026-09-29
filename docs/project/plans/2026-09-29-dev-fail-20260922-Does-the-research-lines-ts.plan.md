<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-29 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new integration test job under jobs/ that validates dashboard digest output
  Verification: bash -n jobs/dashboard-digest-integration.sh

- [ ] Create a verification script under scripts/ that runs the new job and checks exit code
  Verification: bash scripts/run-dashboard-digest-integration.sh && echo "PASS" || echo "FAIL"

- [ ] Update cadence/ to register the new job in the test matrix
  Verification: grep -q "dashboard-digest-integration" cadence/test-matrix.yaml

- [ ] Add a unit test under tests/ for the digest parsing logic
  Verification: make test

- [ ] Verify all existing tests still pass after additions
  Verification: make test
