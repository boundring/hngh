<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-26 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence scheduler script that emits job timestamps based on a configurable interval
  Verification: bash scripts/cadence/emit-timestamps.sh && bash -n scripts/cadence/emit-timestamps.sh

- [ ] Create a test job template under jobs/ that exercises the cadence output
  Verification: make test && grep -q 'cadence' jobs/test-cadence-template.yaml

- [ ] Add a lib helper that validates job template structure before execution
  Verification: python3 lib/validate-template.py && bash -n lib/validate-template.py

- [ ] Write a dashboard digest that aggregates cadence job results
  Verification: bash scripts/digest/aggregate-results.sh && grep -q 'cadence' dashboard/digest-template.md

- [ ] Add a test suite entry that runs the full cadence pipeline end-to-end
  Verification: make test && git diff --stat HEAD~1 | grep -q 'tests/'
