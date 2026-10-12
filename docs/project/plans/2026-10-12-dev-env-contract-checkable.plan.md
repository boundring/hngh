<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-12 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new script `jobs/hngh-baseline-metrics.py` that computes the repository's current commit count and last update timestamp from git log output.
  Verification: bash -n jobs/hngh-baseline-metrics.py && python3 jobs/hngh-baseline-metrics.py
- [ ] Update `cadence/sprint-timeline.md` to include a new row referencing the baseline metrics script in the next sprint's automation backlog.
  Verification: grep -q "hngh-baseline-metrics" cadence/sprint-timeline.md
- [ ] Add a test case in `tests/test_baseline_metrics.py` that asserts the metrics script runs without error and returns an exit code of zero.
  Verification: bash -n tests/test_baseline_metrics.py
- [ ] Commit all changes with message "chore: add baseline metrics tracking for hngh automation".
  Verification: git log --oneline -1
