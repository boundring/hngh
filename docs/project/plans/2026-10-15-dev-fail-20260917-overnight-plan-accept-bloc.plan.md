<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-15 - dev-fail-20260917-overnight-plan-accept-bloc (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new `cadence/` helper script that generates a deterministic daily summary file from the last three logs in `jobs/`.
  Verification: bash -n cadence/generate-digest.sh && ls jobs/run-001.log jobs/run-002.log jobs/run-003.log > /dev/null

- [ ] Create a plain-text commit that registers this new digest script as a runnable entry in `dashboard/`.
  Verification: grep -q "generate-digest" dashboard/hngh-plan.md && git diff --cached --quiet || true

- [ ] Add a unit test under `tests/` that asserts the helper returns a non-empty summary file when invoked.
  Verification: python3 tests/test_digest_helper.py
