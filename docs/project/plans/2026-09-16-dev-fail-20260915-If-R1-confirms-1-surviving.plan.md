<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-16 - dev-fail-20260915-If-R1-confirms-1-surviving (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the research line on make failure-line format and recursive error extraction by adding a parser that tolerates optional recursive depth markers (`make[N]:`) for reliable failing-target extraction.

## Steps

- [ ] Create `lib/make_failure.py` with a function `extract_failing_targets(text)` that returns a list of `(depth, target, code)` tuples using the regex `^make(\[(\d+)\])?: \*\*\* \[([^\]]+)\] Error (\d+)`.
  Verification: python3 -c "import sys; sys.path.insert(0,'lib'); from make_failure import extract_failing_targets; assert extract_failing_targets('make: *** [foo] Error 1') == [(0,'foo',1)]; assert extract_failing_targets('make[2]: *** [bar] Error 2') == [(2,'bar',2)]"
- [ ] Add `tests/test_make_failure.py` with unit tests covering single-level, recursive depth markers, and multi-line input to pin the parser contract.
  Verification: python3 -m unittest discover -s tests -p test_make_failure.py -v
- [ ] Create `scripts/parse_make_log.sh` that reads a log file path from `$1`, pipes it through `python3 lib/make_failure.py --stdin`, and prints one line per failing target as `depth<TAB>target<TAB>code`.
  Verification: bash -n scripts/parse_make_log.sh && printf 'make[1]: *** [a] Error 1\n' | python3 lib/make_failure.py --stdin | grep -q '^1\ta\t1$'
- [ ] Add `tests/test_parse_make_log.sh` that writes a temp log with recursive make errors, invokes `scripts/parse_make_log.sh`, and asserts the expected TSV output.
  Verification: bash tests/test_parse_make_log.sh
- [ ] Update `Makefile` test target to include running `python3 -m unittest discover -s tests -p 'test_*'` so the new parser and script tests are gated by `make test`.
  Verification: make test
