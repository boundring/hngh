<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-11 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `cadence/` entry that runs a single `make test` on the `hngh-automation` tree and records the exit code as a plain text log file
  Verification: `bash -n cadence/run-hngh-test.sh && grep -q 'make test' cadence/run-hngh-test.sh`
- [ ] Create a `scripts/` helper that parses the last 5 lines of `cadence/` logs and prints a one-line summary of pass/fail counts
  Verification: `bash -n scripts/parse-cadence-log.sh && grep -q 'pass/fail' scripts/parse-cadence-log.sh`
- [ ] Wire the helper into a `cadence/` schedule so that running `bash cadence/run-hngh-test.sh` produces a dated summary file under `cadence/`
  Verification: `bash cadence/run-hngh-test.sh && ls -t cadence/ | head -1`
- [ ] Add a `tests/` unit that asserts the summary file contains the word "passed" when `make test` exits zero
  Verification: `python3 tests/assert-summary-passed.py`
- [ ] Commit the new files and run `make test` to confirm the pipeline is green end-to-end
  Verification: `make test`
