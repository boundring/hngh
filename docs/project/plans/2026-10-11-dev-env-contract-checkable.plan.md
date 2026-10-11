<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-11 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `scripts/validate-input.sh` that checks required fields in job input files before execution
  Verification: `bash -n scripts/validate-input.sh`

- [ ] Add a `tests/test-validate-input.sh` that asserts the script rejects malformed input and accepts valid input
  Verification: `bash tests/test-validate-input.sh`

- [ ] Add a `cadence/validate-input.cron` entry that runs `scripts/validate-input.sh` before each job cycle
  Verification: `grep -q 'validate-input' cadence/validate-input.cron`

- [ ] Update `jobs/README.md` to document the new validation step in the pipeline
  Verification: `grep -q 'validate-input' jobs/README.md`

- [ ] Run `make test` to confirm all existing and new tests pass
  Verification: `make test`
