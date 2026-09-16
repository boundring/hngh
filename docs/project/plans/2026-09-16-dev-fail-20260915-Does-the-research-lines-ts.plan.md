<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-16 - dev-fail-20260915-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the research line on duplicated-and-diverged dashboard behaviors by adding a contract test that pins the shared verdict rule to prevent silent drift between surfaces.

## Steps

- [ ] Create `tests/test_verdict_rule_contract.py` with a stdlib-only script that asserts the expected verdict rule logic matches a canonical reference implementation.
  Verification: python3 tests/test_verdict_rule_contract.py

- [ ] Add a grep-based check in `scripts/verify_verdict_drift.sh` that scans for divergent copies of the verdict rule across `jobs/` and `lib/`.
  Verification: bash -n scripts/verify_verdict_drift.sh

- [ ] Wire the drift check into the existing test suite by appending an invocation to `tests/run_tests.sh`.
  Verification: make test

- [ ] Document the shared contract in `digest/VERDICT-RULE-CONTRACT.md` so future changes require explicit divergence justification.
  Verification: grep -q "verdict rule" digest/VERDICT-RULE-CONTRACT.md
