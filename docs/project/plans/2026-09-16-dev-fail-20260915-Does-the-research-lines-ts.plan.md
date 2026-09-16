<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-16 - dev-fail-20260915-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the research line on duplicated-and-diverged dashboard behaviors by adding a contract test that pins the shared verdict rule to prevent silent drift across surfaces.

## Steps

- [ ] Create `tests/test_verdict_rule_contract.py` with a stdlib-only script that asserts the expected verdict rule constants match the canonical values.
  Verification: python3 tests/test_verdict_rule_contract.py

- [ ] Add a `scripts/check_verdict_drift.sh` script that greps for the shared verdict rule literals in the CI workflow and local lib to confirm they are identical.
  Verification: bash -n scripts/check_verdict_drift.sh

- [ ] Update `lib/verdict.py` to export the canonical verdict rule as a single source of truth with a docstring referencing the drift prevention contract.
  Verification: make test

- [ ] Add a digest entry `digest/RESEARCH-BEAT-20260916-verdict-rule-contract.md` documenting the shared contract and the two surfaces it pins.
  Verification: grep -q "verdict rule" digest/RESEARCH-BEAT-20260916-verdict-rule-contract.md
