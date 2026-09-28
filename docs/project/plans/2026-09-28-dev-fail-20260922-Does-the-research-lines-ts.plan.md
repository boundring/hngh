<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-28 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `scripts/validate-hngh.sh` that checks repository structure integrity
  Verification: bash -n scripts/validate-hngh.sh && bash scripts/validate-hngh.sh

- [ ] Add `tests/test-validate-hngh.sh` to exercise the validation script
  Verification: bash -n tests/test-validate-hngh.sh && make test

- [ ] Add `cadence/cadence-rules.md` documenting validation cadence
  Verification: grep -q "validation" cadence/cadence-rules.md

- [ ] Add `lib/hngh-utils.sh` with shared path constants
  Verification: bash -n lib/hngh-utils.sh && grep -q "HNGH_ROOT" lib/hngh-utils.sh

- [ ] Update `dashboard/dashboard-config.yaml` to reference new validation script
  Verification: grep -q "validate-hngh" dashboard/dashboard-config.yaml

- [ ] Add `jobs/job-validate.sh` that runs validation as a job
  Verification: bash -n jobs/job-validate.sh && make test
