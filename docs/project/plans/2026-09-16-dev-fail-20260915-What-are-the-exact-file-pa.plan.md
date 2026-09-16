<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-16 - dev-fail-20260915-What-are-the-exact-file-pa (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the research line on locating the canonical verdict rule and its embedded CI copy, using the make failure-line format findings to build a hermetic extraction script.

## Steps

- [ ] Create `scripts/extract-make-failures.sh` that reads stdin or a file argument and prints lines matching the GNU Make recursive error pattern (`make[0-9]*: \*\*\* \[.*\] Error [0-9]+`).
  Verification: bash -n scripts/extract-make-failures.sh

- [ ] Add `tests/test-extract-make-failures.sh` that pipes a sample multi-level make log into the extractor and asserts the expected error lines are present.
  Verification: bash tests/test-extract-make-failures.sh

- [ ] Create `lib/verdict-rule.txt` containing the single-line canonical verdict rule text (e.g., "PASS" or "FAIL") to serve as the shared source of truth for CI and kernel surfaces.
  Verification: grep -q "FAIL" lib/verdict-rule.txt

- [ ] Add `scripts/check-verdict-drift.sh` that compares the content of `lib/verdict-rule.txt` against an embedded copy in a local file (e.g., `tests/fixtures/ci-embedded-verdict.txt`) and exits non-zero on mismatch.
  Verification: bash scripts/check-verdict-drift.sh

- [ ] Create `tests/fixtures/ci-embedded-verdict.txt` as the initial embedded copy of the verdict rule, identical to `lib/verdict-rule.txt`.
  Verification: diff -q lib/verdict-rule.txt tests/fixtures/ci-embedded-verdict.txt
