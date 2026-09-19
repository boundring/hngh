<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-19 - dev-fail-20260917-Do-audit-records-in-hngh-a (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line for **hngh-automation** by establishing a deterministic, scriptable development cadence that enforces strict verification gates through `make test` and shell syntax validation.

## Steps

- [ ] Create `lib/validate.sh` to encapsulate common pre-commit checks and ensure it passes bash syntax validation
  Verification: `bash -n lib/validate.sh`
- [ ] Add a new job definition in `jobs/hngh-dev-plan.yml` that triggers the cadence pipeline on branch updates
  Verification: `grep -q "hngh-dev-plan" jobs/hngh-dev-plan.yml`
- [ ] Implement `scripts/run-cadence.sh` to orchestrate the development plan execution with explicit error handling
  Verification: `bash -n scripts/run-cadence.sh`
- [ ] Update `cadence/plan.md` to document the new normal-risk workflow and verification requirements
  Verification: `grep -q "normal-risk" cadence/plan.md`
- [ ] Execute the full test suite to ensure no regressions in the hngh-automation repository
  Verification: `make test`
