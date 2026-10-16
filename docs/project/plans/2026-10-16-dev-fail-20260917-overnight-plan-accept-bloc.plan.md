<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-16 - dev-fail-20260917-overnight-plan-accept-bloc (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `scripts/validate-plan.sh` that checks plan step count and verification presence
  Verification: bash scripts/validate-plan.sh

- [ ] Add a `tests/test-plan-format.sh` that validates step indentation and verification syntax
  Verification: bash tests/test-plan-format.sh

- [ ] Add a `cadence/plan-rules.sh` that enforces normal-risk gating before plan admission
  Verification: bash cadence/plan-rules.sh

- [ ] Add a `lib/plan-validator.py` (stdlib only) that parses plan body and rejects forbidden paths
  Verification: python3 lib/plan-validator.py

- [ ] Add a `dashboard/plan-summary.sh` that extracts step count and verification count from plan
  Verification: bash dashboard/plan-summary.sh
