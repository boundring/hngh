<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-26 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new cadence job template for daily digest generation
  Verification: `bash -n cadence/daily-digest-job.sh`

- [ ] Create verification script to validate digest output format
  Verification: `python3 scripts/validate-digest-format.py`

- [ ] Add unit test for digest generation pipeline
  Verification: `make test`

- [ ] Update cadence README with new job documentation
  Verification: `grep -q "daily-digest" cadence/README.md`

- [ ] Add integration test for end-to-end digest flow
  Verification: `bash -n tests/integration/test-digest-flow.sh`
