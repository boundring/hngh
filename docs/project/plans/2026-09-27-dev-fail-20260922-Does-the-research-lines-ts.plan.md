<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-27 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence job that runs a basic syntax check on lib files
  Verification: bash -n cadence/check-lib.sh

- [ ] Create the cadence script under cadence/check-lib.sh
  Verification: bash cadence/check-lib.sh

- [ ] Add a test for the cadence script in tests/
  Verification: make test

- [ ] Verify the script passes bash syntax check
  Verification: bash -n cadence/check-lib.sh

- [ ] Confirm no forbidden paths are modified
  Verification: git grep -n "provider\|credential\|systemd\|secret" -- hngh-automation/

- [ ] Run the full test suite to ensure no regressions
  Verification: make test
