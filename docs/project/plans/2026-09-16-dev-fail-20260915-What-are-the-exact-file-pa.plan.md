<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-16 - dev-fail-20260915-What-are-the-exact-file-pa (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the research line on locating the canonical verdict rule paths and verifying Make failure-line format compatibility, grounding the automation's CI verification logic in concrete file evidence.

## Steps

- [ ] Create a script `scripts/verify-verdict-rule-paths.sh` that checks for the existence of candidate verdict rule files (e.g., `kernel/verdict.py`, `.github/workflows/ci-verify.yml`) and logs their presence or absence.
  Verification: bash -n scripts/verify-verdict-rule-paths.sh

- [ ] Create a script `scripts/extract-make-errors.sh` that parses Make output for recursive error lines matching the pattern `make[N]: *** [target] Error M` where N >= 1, using standard shell tools.
  Verification: bash -n scripts/extract-make-errors.sh

- [ ] Add a test file `tests/test-verdict-rule-paths.sh` that runs the path verification script against a mock directory structure to confirm it correctly identifies present and absent files.
  Verification: make test

- [ ] Add a test file `tests/test-make-error-extraction.sh` that feeds sample recursive Make error output to the extraction script and asserts correct parsing of nested targets.
  Verification: make test

- [ ] Create a digest entry `digest/VERDICT-RULE-PATHS-RECORD.md` documenting the resolved file paths for the canonical verdict rule and the embedded CI copy, citing the verification results from the scripts.
  Verification: grep -q "verdict.py" digest/VERDICT-RULE-PATHS-RECORD.md
