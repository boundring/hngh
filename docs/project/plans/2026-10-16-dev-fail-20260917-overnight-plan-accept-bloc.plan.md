<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-16 - dev-fail-20260917-overnight-plan-accept-bloc (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add `cadence/README.md` documenting the automated research-line ingestion workflow for hngh-automation.
  Verification: bash -n cadence/README.md && grep -q "hngh" cadence/README.md
- [ ] Create `scripts/generate_plan.sh` that reads adopted findings and emits a templated development plan into `cadence/draft-plan.md`.
  Verification: bash -n scripts/generate_plan.sh && bash scripts/generate_plan.sh 2>&1 | grep -q "hngh"
- [ ] Add `tests/test_plan_generation.py` using stdlib to assert that generated plans contain exactly one rationale line and a '## Steps' header.
  Verification: python3 tests/test_plan_generation.py
- [ ] Update `.gitignore` in `jobs/` to exclude any build artifacts or credential traces from the plan directory.
  Verification: grep -q "credential" jobs/.gitignore || grep -q ".env" jobs/.gitignore
