<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-27 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a lib/assertion helper that validates job output schemas before cadence dispatch
  Verification: bash -n lib/assertion.py && python3 lib/assertion.py --check-schema

- [ ] Create a cadence runner script that gates job execution on assertion pass
  Verification: bash -n cadence/runner.sh && bash cadence/runner.sh --dry-run

- [ ] Add a tests/assertion test suite that exercises the helper against sample outputs
  Verification: make test && grep -c "assertion" tests/assertion_test.sh

- [ ] Update dashboard digest to include assertion pass/fail counts per job
  Verification: bash -n dashboard/digest.py && python3 dashboard/digest.py --sample

- [ ] Add a jobs/scheduler hook that prunes failed assertion logs after 24h
  Verification: bash -n jobs/scheduler.sh && grep -q "prune" jobs/scheduler.sh

- [ ] Verify all new paths pass lint and integration test before merge
  Verification: make test && bash -n lib/assertion.py && bash -n cadence/runner.sh
