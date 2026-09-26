<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-26 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new job script that validates hngh-automation commit hygiene by checking for required metadata headers
  Verification: bash scripts/validate-commit-metadata.sh
- [ ] Create a test case that exercises the commit metadata validation logic
  Verification: make test
- [ ] Add a cadence entry that triggers the validation job on every push to the automation branch
  Verification: grep -q "validate-commit-metadata" cadence/schedule.yaml
- [ ] Verify the new cadence entry is syntactically valid by parsing the schedule file
  Verification: python3 cadence/parse-schedule.py
- [ ] Run the full test suite to confirm no regressions from the new validation job
  Verification: make test
