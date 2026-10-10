<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-10 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Rename the existing `cadence/scheduler.py` stub to include a timestamp-aware wrapper that records the current second before delegating to the original loader
  Verification: bash scripts/check-scheduler-timestamp.sh && python3 -c "import cadence.scheduler; assert hasattr(cadence.scheduler, 'now')"

- [ ] Add a `lib/normalize_path.py` utility that converts any relative job reference into an absolute path under `jobs/` and is imported by the scheduler
  Verification: bash scripts/check-path-normalize.sh && python3 -c "from lib.normalize_path import normalize; assert '/' in normalize('foo/bar')"

- [ ] Extend `cadence/run.py` to read the normalized path from the new helper before invoking any worker, logging both values for traceability
  Verification: make test

- [ ] Insert a dry-run flag into `dashboard/monitor.py` that prints the planned execution tree without spawning processes and exits with status 0 on success
  Verification: python3 dashboard/monitor.py --dry-run > /dev/null && echo "dry run passed"

- [ ] Create `tests/test_plan_integration.sh` that exercises the full path normalization chain end-to-end against a synthetic job manifest and asserts no side effects occur
  Verification: bash tests/test_plan_integration.sh
