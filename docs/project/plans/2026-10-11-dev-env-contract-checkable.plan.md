<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-11 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Rationale: Implement a lightweight log aggregation pipeline to classify job failure modes, advancing the research line of automated observability for hngh-automation without touching credentials, kernel, or security posture.

## Steps

- [ ] Create a shell script at `scripts/parse-logs.sh` that aggregates and categorizes job output into success/failure buckets.
  Verification: bash -n scripts/parse-logs.sh

- [ ] Add a unit test at `tests/test_parse_logs.sh` that asserts the script exits cleanly and produces categorized output for sample input.
  Verification: bash tests/test_parse_logs.sh

- [ ] Update `cadence/nightly.sh` to invoke `scripts/parse-logs.sh` before the existing summary generation step.
  Verification: bash -n cadence/nightly.sh

- [ ] Append a summary entry to `digest/summary.md` documenting the new log aggregation capability.
  Verification: git grep -c "log aggregation" digest/summary.md

- [ ] Run the full test suite to confirm no regressions were introduced by the new scripts.
  Verification: make test
