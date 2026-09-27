<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-27 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `scripts/hngh-automation-cadence.sh` entrypoint that prints cadence metadata and exits 0
  Verification: bash -n scripts/hngh-automation-cadence.sh && make test

- [ ] Add `tests/test_cadence.sh` that asserts the cadence script runs and returns 0
  Verification: bash tests/test_cadence.sh && make test

- [ ] Add `cadence/hngh-automation-cadence.yaml` describing the cadence schedule and scope
  Verification: grep -q 'hngh-automation' cadence/hngh-automation-cadence.yaml && make test

- [ ] Add `lib/hngh-automation-cadence.py` stdlib-only helper for cadence state inspection
  Verification: python3 -c "import sys; sys.path.insert(0, 'lib'); import hngh_automation_cadence; print('ok')" && make test

- [ ] Add `dashboard/hngh-automation-cadence.md` documenting the cadence line and its research scope
  Verification: grep -q 'hngh-automation' dashboard/hngh-automation-cadence.md && make test

This plan implements the **hngh-automation cadence** research line by introducing a runnable cadence entrypoint, its test coverage, schedule metadata, a stdlib-only inspection helper, and a dashboard document — all as plain commits gated by `make test`.
