<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-16 - dev-fail-20260917-overnight-plan-accept-bloc (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a shell script in `scripts/` that validates hngh-automation commit hygiene
  Verification: `bash -n scripts/hngh-commit-hygiene.sh`
- [ ] Add a test job in `jobs/` that runs the hygiene script as part of the pipeline
  Verification: `make test`
- [ ] Add a cadence entry in `cadence/` that schedules the hygiene check
  Verification: `bash -n cadence/hngh-cadence-check.sh`
- [ ] Add a lib helper in `lib/` that extracts commit metadata for verification
  Verification: `bash -n lib/hngh-commit-metadata.sh`
- [ ] Add a test in `tests/` that asserts the lib helper returns expected output
  Verification: `bash -n tests/hngh-commit-metadata-test.sh`
- [ ] Add a dashboard snippet in `dashboard/` that displays hygiene status
  Verification: `bash -n dashboard/hngh-hygiene-dashboard.sh`
