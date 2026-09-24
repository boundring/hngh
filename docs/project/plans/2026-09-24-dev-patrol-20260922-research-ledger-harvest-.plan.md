<!-- plan: status=accepted risk=normal accepted=2026-09-24T06:04:02Z -->
# 2026-09-24 - dev-patrol-20260922-research-ledger-harvest- (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new job template for structured finding ingestion under `jobs/`
  Verification: `bash -n jobs/finding-ingest.sh`

- [ ] Create a verification script that confirms the new job template parses correctly
  Verification: `bash jobs/finding-ingest.sh --dry-run`

- [ ] Add a unit test for the finding ingestion parser under `tests/`
  Verification: `make test`

- [ ] Create a cadence entry that triggers the new ingestion job on schedule
  Verification: `bash -n cadence/finding-cadence.sh`

- [ ] Add a dashboard snippet that displays ingestion job status
  Verification: `bash -n dashboard/ingest-status.sh`
