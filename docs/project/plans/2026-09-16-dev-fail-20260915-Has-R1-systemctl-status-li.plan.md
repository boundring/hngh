<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-16 - dev-fail-20260915-Has-R1-systemctl-status-li (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the research line on duplicated-and-diverged dashboard behaviors by adding a contract test that pins the shared verdict rule logic to prevent silent divergence between surfaces.

## Steps

- [ ] Create `lib/verdict.py` containing the canonical verdict rule function with deterministic inputs and outputs.
  Verification: python3 -c "import sys; sys.path.insert(0, 'lib'); from verdict import evaluate_verdict; assert evaluate_verdict('pass') == 'pass'"
- [ ] Add `tests/test_verdict_contract.py` that imports the shared rule from `lib/verdict.py` and asserts specific pass/fail boundary cases.
  Verification: make test
- [ ] Update any existing dashboard or CI script under `scripts/` or `dashboard/` that embeds verdict logic to import from `lib/verdict.py` instead of duplicating the rule inline.
  Verification: grep -R "def evaluate_verdict" scripts/ dashboard/ | wc -l
- [ ] Add a regression test case in `tests/test_verdict_contract.py` for a previously diverged edge case (e.g., ambiguous status string) to lock the shared contract.
  Verification: make test
