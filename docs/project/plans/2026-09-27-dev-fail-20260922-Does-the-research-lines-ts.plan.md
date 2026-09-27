<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-27 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `dry-run` flag to the cadence runner that parses job definitions without executing them
  Verification: `bash -n cadence/dry-run.sh`

- [ ] Create a sample job config under `jobs/sample-config.yaml` that exercises the dry-run path
  Verification: `bash cadence/dry-run.sh --config jobs/sample-config.yaml`

- [ ] Add a test script in `tests/test-dry-run.sh` that validates dry-run output against expected parse results
  Verification: `bash tests/test-dry-run.sh`

- [ ] Update `make test` to include the new dry-run test target
  Verification: `make test`
