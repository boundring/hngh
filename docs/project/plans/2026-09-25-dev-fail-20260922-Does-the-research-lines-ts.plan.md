<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-25 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a test script that validates the cadence job runner exits cleanly on a minimal input
  Verification: bash tests/cadence_runner_smoke.sh

- [ ] Create a helper script that parses a job manifest and reports its status
  Verification: bash -n scripts/manifest_parser.sh

- [ ] Add a dashboard snippet that logs cadence job completion timestamps
  Verification: grep -q "timestamp" dashboard/cadence_log.sh

- [ ] Write a test that confirms the digest generator produces output for a sample job
  Verification: python3 tests/digest_generator_test.py

- [ ] Commit all changes and run the full test suite to confirm no regressions
  Verification: make test
