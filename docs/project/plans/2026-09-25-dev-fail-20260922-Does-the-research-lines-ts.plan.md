<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-25 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new job template under `jobs/` for batch digest generation
  Verification: `bash -n jobs/batch-digest.sh`

- [ ] Create a verification script in `scripts/` to validate digest output format
  Verification: `python3 scripts/validate-digest.py`

- [ ] Add a test case in `tests/` that exercises the new job template
  Verification: `make test`

- [ ] Update `cadence/` to register the new job in the run schedule
  Verification: `bash -n cadence/schedule.yaml`

- [ ] Add a dashboard snippet in `dashboard/` to surface digest metrics
  Verification: `bash -n dashboard/metrics-view.sh`

- [ ] Run full test suite to confirm no regressions
  Verification: `make test`
