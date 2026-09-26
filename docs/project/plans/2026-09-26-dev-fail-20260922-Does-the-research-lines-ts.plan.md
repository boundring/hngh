<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-26 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new job script under `jobs/` that validates input file existence before processing
  Verification: `bash -n jobs/validate-input.sh`

- [ ] Add a test script under `tests/` that asserts the validation job exits non-zero on missing input
  Verification: `bash tests/test-validate-input.sh`

- [ ] Add a cadence entry under `cadence/` that schedules the validation job on cron
  Verification: `grep -q "validate-input" cadence/cron.list`

- [ ] Add a helper library under `lib/` that provides a shared file-existence check function
  Verification: `bash -n lib/file-check.sh`

- [ ] Add a dashboard snippet under `dashboard/` that displays validation job status
  Verification: `grep -q "validate-input" dashboard/status.json`

- [ ] Run full test suite to confirm all new steps integrate cleanly
  Verification: `make test`
