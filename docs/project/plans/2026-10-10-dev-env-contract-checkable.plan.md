<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-10 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a basic test script that validates hngh-automation job scheduling logic
  Verification: `bash -n tests/test_scheduling.sh`

- [ ] Create a helper script to format and display job cadence output
  Verification: `bash scripts/format_cadence.sh`

- [ ] Update the dashboard digest to include a new metrics summary section
  Verification: `grep -q "metrics_summary" dashboard/digest.md`

- [ ] Add a simple validation check for job configuration files
  Verification: `python3 scripts/validate_jobs.py`

- [ ] Commit all changes and run the full test suite
  Verification: `make test`
