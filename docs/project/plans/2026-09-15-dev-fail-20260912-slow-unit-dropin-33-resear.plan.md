<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-15 - dev-fail-20260912-slow-unit-dropin-33-resear (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements bounded instrumentation for the slow-unit dropin re-fire and dashboard link integrity by adding completion markers and canonical rule diffing to hngh-automation. It addresses the structural bimodality in execution classes and semantic disagreements between enumerators and renderers without altering kernel or security posture.

## Steps

- [ ] Add a completion marker flag to `scripts/dropin:33-research-beat.sh` to prevent re-firing of slow-mode rows
  Verification: bash -n scripts/dropin:33-research-beat.sh

- [ ] Create `lib/verdict-rule-diff.sh` to compare embedded CI rules against the kernel's canonical source
  Verification: bash -n lib/verdict-rule-diff.sh

- [ ] Update `jobs/dashboard-link-check.sh` to validate plan enumerator links against renderer artifacts
  Verification: bash -n jobs/dashboard-link-check.sh

- [ ] Add a test case in `tests/test-dropin-completion.sh` to verify slow-mode rows are marked complete
  Verification: make test

- [ ] Integrate the verdict rule diff check into `cadence/patrol-verdict.sh` to prevent drift
  Verification: bash -n cadence/patrol-verdict.sh
