<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-14 - dev-fail-20260913-Has-the-upstream-guardrail (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the research line "Has the upstream guardrail bug from 2026-08-25 been resolved... and does `lib/automation.py` now handle the corrected CLI contract without errors?" by verifying downstream conformance to the post-fix kernel contract.

## Steps

- [ ] Inspect `lib/automation.py` to identify the exact CLI arguments passed to the hngh kernel binary.
  Verification: grep -n "subprocess\|Popen\|call" lib/automation.py | head -20
- [ ] Add a unit test in `tests/test_automation_cli_contract.py` that mocks the subprocess call and asserts the argument list matches the corrected post-2026-08-25 contract.
  Verification: python3 tests/test_automation_cli_contract.py
- [ ] Execute the repository test suite to ensure the new contract test passes and no regressions are introduced.
  Verification: make test
- [ ] Verify that `lib/automation.py` contains no references to the deprecated pre-fix CLI flags identified in the research line.
  Verification: grep -v "deprecated_flag" lib/automation.py | grep -i "old_contract_flag" || echo "no_deprecated_flags_found"
- [ ] Commit the changes with a message referencing the research line ID `fail-20260913-Has-the-upstream-guardrail-bug-from-2026`.
  Verification: git log -1 --pretty=format:"%s" | grep "fail-20260913-Has-the-upstream-guardrail-bug-from-2026"
