<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-12 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `cadence/run.sh` script that iterates over `jobs/` entries in sorted order and executes each one
  Verification: bash -n cadence/run.sh

- [ ] Add a `cadence/README.md` documenting the run order and how new jobs are discovered
  Verification: grep -q "run order" cadence/README.md

- [ ] Add a `tests/test_cadence.sh` script that asserts `cadence/run.sh` exists and is executable
  Verification: bash tests/test_cadence.sh

- [ ] Add a `lib/cadence.sh` helper that provides `cadence_next_job` and `cadence_done` functions
  Verification: bash -n lib/cadence.sh

- [ ] Add a `dashboard/cadence_status.json` template file with initial empty structure
  Verification: grep -q "cadence_status" dashboard/cadence_status.json

- [ ] Add a `digest/cadence_digest.sh` script that logs cadence run completion to `digest/`
  Verification: bash -n digest/cadence_digest.sh
