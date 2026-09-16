<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-16 - dev-fail-20260915-What-are-the-exact-file-pa (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the research line on canonical verdict rule paths and make failure-line format by adding a hermetic, stdlib-only parser for recursive GNU Make error lines and a CI workflow stub that pins the embedded verdict rule path.

## Steps

- [ ] Add `lib/verdict_rule.py` exposing `parse_make_errors(text: str) -> list[tuple[int, str, int]]` that extracts `(depth, target, code)` from lines matching `^make(\[(\d+)\])?: \*\*\* \[([^\]]+)\] Error (\d+)`.
  Verification: python3 -c "import sys; sys.path.insert(0,'lib'); from verdict_rule import parse_make_errors; assert parse_make_errors('make: *** [t] Error 1\nmake[2]: *** [a/b] Error 3') == [(0,'t',1),(2,'a/b',3)]"
- [ ] Add `tests/test_verdict_rule.py` with three cases: single-level, recursive depth, and non-matching noise lines.
  Verification: make test
- [ ] Add `scripts/verify-verdict-rule.sh` that runs the parser against a fixture string containing `make[1]: *** [subdir/target.o] Error 1` and exits non-zero if no depth-1 tuple is returned.
  Verification: bash -n scripts/verify-verdict-rule.sh && bash scripts/verify-verdict-rule.sh
- [ ] Add `jobs/ci-verify.yml` (a plain YAML file, not a GitHub workflow) that records the embedded verdict rule path as `lib/verdict_rule.py` and invokes `scripts/verify-verdict-rule.sh`.
  Verification: grep -q 'lib/verdict_rule.py' jobs/ci-verify.yml && grep -q 'scripts/verify-verdict-rule.sh' jobs/ci-verify.yml
