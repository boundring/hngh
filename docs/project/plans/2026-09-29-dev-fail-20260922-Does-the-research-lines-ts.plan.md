<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-29 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new cadence job template for hourly digest generation
  Verification: bash -n cadence/hourly-digest.sh

- [ ] Create a verification script that confirms the new cadence job exists
  Verification: grep -q 'hourly-digest' cadence/hourly-digest.sh

- [ ] Add a test case for the new cadence job template
  Verification: make test

- [ ] Update the dashboard manifest to include the new job
  Verification: grep -q 'hourly-digest' dashboard/manifest.json

- [ ] Run the full test suite to confirm no regressions
  Verification: make test
