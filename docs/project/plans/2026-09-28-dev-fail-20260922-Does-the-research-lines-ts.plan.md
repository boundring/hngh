<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-28 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence helper script that validates job output schemas before ingestion
  Verification: bash -n cadence/schema-validator.sh

- [ ] Create a test fixture that generates sample job outputs for schema validation
  Verification: python3 tests/test_schema_fixtures.py

- [ ] Update the digest pipeline to call the schema validator before processing
  Verification: make test

- [ ] Add a dashboard view showing schema validation success rates over time
  Verification: bash -n dashboard/schema-metrics.sh

- [ ] Write integration test that exercises the full validation pipeline end-to-end
  Verification: make test

- [ ] Document the schema validation flow in the jobs README
  Verification: grep -q "schema validation" jobs/README.md
