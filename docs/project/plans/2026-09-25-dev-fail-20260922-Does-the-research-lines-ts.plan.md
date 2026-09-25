<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-25 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new cadence job template for automated data validation under `cadence/jobs/data-validation.yaml`
  Verification: `bash -n cadence/jobs/data-validation.yaml`

- [ ] Create a verification script under `scripts/validate-data-job.sh` that checks the new job template structure
  Verification: `bash scripts/validate-data-job.sh`

- [ ] Add unit tests for the data validation job under `tests/cadence/data-validation.test.sh`
  Verification: `make test`

- [ ] Update the cadence runner to register the new job template under `lib/cadence-registry.py`
  Verification: `python3 -c "import sys; sys.path.insert(0, 'lib'); from cadence_registry import registry; print(len(registry))"`

- [ ] Add a dashboard snippet under `dashboard/data-validation.html` to display validation results
  Verification: `bash -n dashboard/data-validation.html`

- [ ] Create a digest template under `digest/data-validation.md` for automated result reporting
  Verification: `bash -n digest/data-validation.md`
