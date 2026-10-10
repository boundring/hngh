<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-10 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the research line **hngh-automation: lib-output-parsing-standardization** by introducing a reusable shell utility for normalizing job stdout before downstream digest aggregation.

## Steps

- [ ] Create `scripts/parse_output.sh` containing a function to validate and normalize job stdout.
  Verification: `bash -n scripts/parse_output.sh`

- [ ] Integrate `scripts/parse_output.sh` into `cadence/run_job.sh` to normalize output before logging.
  Verification: `bash -n cadence/run_job.sh`

- [ ] Add `tests/test_parse_output.sh` asserting the parser handles empty and multiline inputs.
  Verification: `bash tests/test_parse_output.sh`

- [ ] Update `digest/aggregate.sh` to consume the normalized output from `cadence/run_job.sh`.
  Verification: `bash -n digest/aggregate.sh`

- [ ] Execute `make test` to confirm all new and existing tests pass.
  Verification: `make test`
