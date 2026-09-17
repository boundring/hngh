<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-17 - dev-fail-20260917-Does-the-hngh-build-policy (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Create `scripts/validate_plan.py` to parse and validate the development plan structure
  Verification: python3 scripts/validate_plan.py
- [ ] Add unit tests for plan validation logic in `tests/test_validate_plan.py`
  Verification: make test
- [ ] Update `lib/plan_parser.sh` to support new step format with verification lines
  Verification: bash -n lib/plan_parser.sh
- [ ] Create `cadence/check_plan_integrity.sh` to verify plan steps are independently verifiable
  Verification: bash cadence/check_plan_integrity.sh
