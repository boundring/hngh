<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-27 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence verification script that validates job output format
  Verification: bash scripts/cadence-verify.sh

- [ ] Update make test to include the new verification script
  Verification: make test

- [ ] Add a dashboard digest helper that formats run summaries
  Verification: python3 dashboard/digest-helper.py

- [ ] Create a lib utility for safe path resolution
  Verification: bash -n lib/path-utils.sh

- [ ] Add tests for the path utility module
  Verification: make test

- [ ] Verify all scripts pass syntax checks
  Verification: bash -n scripts/cadence-verify.sh && bash -n lib/path-utils.sh
