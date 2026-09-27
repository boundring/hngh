<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-27 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new job pipeline definition under jobs/ for batch report generation
  Verification: bash -n jobs/batch-report-pipeline.sh

- [ ] Create a verification script that confirms pipeline output lands in digest/
  Verification: python3 scripts/verify_digest_path.py

- [ ] Add a cadence entry mapping the new pipeline to its expected run frequency
  Verification: bash -n cadence/pipeline-schedule.sh

- [ ] Extend lib/ to include a shared utility for normalizing pipeline output
  Verification: bash -n lib/normalize_output.py

- [ ] Add a test case covering the new pipeline end-to-end
  Verification: make test

- [ ] Update dashboard/ to reflect the new pipeline status
  Verification: bash -n dashboard/pipeline-status.sh
