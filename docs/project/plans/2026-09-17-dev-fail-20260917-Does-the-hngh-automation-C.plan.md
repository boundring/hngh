<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z -->
# 2026-09-17 - dev-fail-20260917-Does-the-hngh-automation-C (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the pipeline-script-hardening research line by adding syntax validation, test coverage for shared helpers, and config linting across jobs, cadence, and dashboard surfaces so that malformed definitions are caught before they reach a live run.

## Steps

- [ ] Add scripts/check_job_scripts.sh that walks every .sh file under jobs/ and exits non-zero on any unparseable job script
  Verification: bash -n scripts/check_job_scripts.sh

- [ ] Extend tests/test_pipeline_helpers.py with unit cases for lib/pipeline_helpers.py covering empty-input and malformed-manifest paths
  Verification: make test

- [ ] Create cadence/validate_cadence.py using only stdlib to assert every schedule entry references an existing job name under jobs/
  Verification: python3 cadence/validate_cadence.py

- [ ] Add tests/test_digest_render.py with a fixture asserting the rendered digest structure matches expected keys and ordering
  Verification: make test

- [ ] Add dashboard/lint_dashboard.js that parses the dashboard config file and exits non-zero on unknown or duplicate top-level keys
  Verification: node --check dashboard/lint_dashboard.js
