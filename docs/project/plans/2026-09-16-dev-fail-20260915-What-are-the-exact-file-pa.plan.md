<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-16 - dev-fail-20260915-What-are-the-exact-file-pa (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements fail-20260915-What-make-version-does-the-repo-s-toolch by adding a local stdlib-only parser and fixture for GNU Make failure lines in hngh-automation. This lets failing-target extraction tolerate recursive `make[N]:` markers without depending on an exact Make version or kernel paths.

## Steps

- [ ] Add scripts/hngh_make_failure_parser.py that accepts an optional log-file path, extracts the first failing target from `make`, optional `[N]`, `*** [target] Error N` lines, and runs a built-in self-test when invoked without arguments.
  Verification: python3 scripts/hngh_make_failure_parser.py
- [ ] Add tests/fixtures/make-failure-lines.txt containing single-level and recursive Make failure examples, including `make[2
