<!-- plan: status=accepted risk=normal accepted=2026-09-20T01:03:56Z -->
# 2026-09-20 - dev-fail-20260917-What-is-the-absolute-path- (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line focused on enhancing the reliability of the `hngh` automation pipeline by introducing robust shell script validation and structured job definitions under normal-risk constraints.

## Steps

- [ ] Create a new shell script at `scripts/validate_pipeline.sh` that checks for required environment variables without executing external commands.
  Verification: bash -n scripts/validate_pipeline.sh

- [ ] Add a Python standard library test script at `tests/test_job_config.py` to validate the structure of job configuration files using only built-in modules.
  Verification: python3 tests/test_job_config.py

- [ ] Define a new job definition file at `jobs/pipeline_check.json` specifying the sequence for running validation scripts.
  Verification: grep -q "validate_pipeline" jobs/pipeline_check.json

- [ ] Update the cadence configuration at `cadence/schedule.yaml` to include the new pipeline check job in the execution order.
  Verification: grep -q "pipeline_check" cadence/schedule.yaml

- [ ] Execute the full test suite to ensure no regressions were introduced by the new scripts and configurations.
  Verification: make test
