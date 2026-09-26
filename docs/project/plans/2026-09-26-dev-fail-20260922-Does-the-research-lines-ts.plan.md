<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-26 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence helper that validates job output schema before ingestion
  Verification: bash -n cadence/schema-validator.sh
- [ ] Create a lib utility for safe path resolution under jobs/
  Verification: python3 lib/path_resolver.py
- [ ] Add a test that exercises the schema validator end-to-end
  Verification: bash -n tests/test_schema_validator.sh
- [ ] Wire the validator into the existing cadence pipeline
  Verification: make test
- [ ] Add a dashboard snippet that reports validation pass/fail counts
  Verification: bash -n dashboard/validation_report.sh
