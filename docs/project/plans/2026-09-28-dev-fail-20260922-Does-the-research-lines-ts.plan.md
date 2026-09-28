<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-28 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence scheduler entry for the daily digest pipeline in `cadence/daily-digest.yaml`
  Verification: `bash -n cadence/daily-digest.yaml`

- [ ] Create a verification script in `scripts/verify-cadence-entry.sh` that checks the YAML is parseable and references exist
  Verification: `bash scripts/verify-cadence-entry.sh`

- [ ] Add a test case in `tests/cadence/daily-digest.test` that asserts the entry loads without errors
  Verification: `bash -n tests/cadence/daily-digest.test`

- [ ] Update `lib/cadence-loader.py` to include parsing of the new daily-digest entry format
  Verification: `python3 -c "import lib.cadence-loader; print('ok')"`

- [ ] Add a dashboard snippet in `dashboard/cadence-status.md` documenting the new entry
  Verification: `grep -q 'daily-digest' dashboard/cadence-status.md`

- [ ] Run `make test` to confirm all changes pass the existing test suite
  Verification: `make test`
