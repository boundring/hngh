<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-28 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new job type template for batch data ingestion under jobs/batch-ingest/
  Verification: bash -n jobs/batch-ingest/template.sh

- [ ] Extend cadence scheduler to recognize the new batch-ingest job type
  Verification: bash -n cadence/scheduler.c

- [ ] Add unit tests for batch-ingest job execution path
  Verification: make test

- [ ] Update dashboard job registry to include batch-ingest type
  Verification: grep -q "batch-ingest" dashboard/registry.json

- [ ] Create a helper script for batch-ingest configuration validation
  Verification: python3 scripts/validate_batch_ingest_config.py
