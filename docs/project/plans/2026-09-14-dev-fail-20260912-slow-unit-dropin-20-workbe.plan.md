<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z -->
# 2026-09-14 - dev-fail-20260912-slow-unit-dropin-20-workbe (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the research line fail-20260910-overnight-plan-accept-blocked-2026-09-09-stall-recovery-and-operator-surfaces by adding a deterministic parser check to prevent auto-accept failures caused by missing Verification lines.

## Steps

- [ ] Create scripts/validate_plan_format.py that parses plan text and asserts every step block contains a "Verification:" line
  Verification: python3 scripts/validate_plan_format.py --help

- [ ] Add tests/test_validate_plan_format.py with a fixture containing a step missing the Verification field to assert parser rejection
  Verification: make test

- [ ] Update jobs/acceptance-gate.sh to invoke the new validator before marking a plan as parse_pass
  Verification: bash -n jobs/acceptance-gate.sh

- [ ] Add digest/RESEARCH-BEAT-fail-20260910-overnight-plan-accept-blocked-2026-09-09-stall-recovery-and-operator-surfaces.md documenting the deterministic failure mode and parser fix
  Verification: grep -q "deterministic" digest/RESEARCH-BEAT-fail-20260910-overnight-plan-accept-blocked-2026-09-09-stall-recovery-and-operator-surfaces.md
