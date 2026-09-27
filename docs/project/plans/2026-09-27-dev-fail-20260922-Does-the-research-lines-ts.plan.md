<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-27 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Rationale: This implements the research line on "incremental test scaffolding for cadence-driven automation" by adding a reusable test helper that validates job completion states without touching provider configuration.

## Steps

- [ ] Add a test helper function in lib/ that validates job completion
  Verification: bash -n lib/test_helpers.sh

- [ ] Create a verification script in scripts/ that checks automation output format
  Verification: bash scripts/verify_output.sh

- [ ] Update existing test in tests/ to use the new helper
  Verification: make test
