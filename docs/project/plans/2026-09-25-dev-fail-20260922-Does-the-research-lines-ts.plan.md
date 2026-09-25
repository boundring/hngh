<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-25 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new cadence job file for daily digest generation
  Verification: bash -n cadence/daily-digest.sh
- [ ] Add unit test for the digest job's output format
  Verification: make test
- [ ] Add a script to validate digest output schema
  Verification: python3 scripts/validate-digest-schema.py
- [ ] Add integration test for the full cadence pipeline
  Verification: make test
- [ ] Add a dashboard job to track cadence execution history
  Verification: bash -n dashboard/cadence-tracker.sh
- [ ] Verify all new files pass syntax checks
  Verification: bash -n cadence/daily-digest.sh && bash -n dashboard/cadence-tracker.sh && python3 scripts/validate-digest-schema.py
