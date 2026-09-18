<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z -->
# 2026-09-15 - dev-fail-20260912-slow-unit-dropin-33-resear (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the instrumentation and consistency verification lines from `fail-20260912-slow-unit-dropin-33-research-beat.sh` and `fail-20260914-Does-the-github-ci-workflow-definition-c`, focusing on adding bounded logging for slow-unit execution classes and enforcing a diff check against the canonical patrol verdict rule to prevent surface drift.

## Steps

- [ ] Create a helper script in `scripts/` that logs execution class boundaries (fast/slow path) for dropin units, capturing wall-time and median metrics to a local JSONL file.
  Verification: bash -n scripts/log-dropin-execution-class.sh
- [ ] Add a unit test in `tests/` that verifies the new logging script correctly partitions rows into fast-path (<1s) and slow-path (>=1s) based on simulated timing data.
  Verification: make test
- [ ] Create a verification script in `scripts/` that diffs the embedded patrol verdict rule in the CI workflow definition against the canonical rules file path to detect drift.
  Verification: bash -n scripts/check-verdict-rule-drift.sh
- [ ] Integrate the drift check into the existing CI workflow by adding a step that executes the new verification script and fails if differences are detected.
  Verification: grep -q "check-verdict-rule-drift" .github/workflows/ci.yml
- [ ] Update the dashboard digest generation logic in `digest/` to include a summary of slow-unit re-fires based on the new execution class logs, ensuring no sensitive data is exposed.
  Verification: make test
