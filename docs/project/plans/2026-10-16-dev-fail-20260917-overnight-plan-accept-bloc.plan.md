<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-16 - dev-fail-20260917-overnight-plan-accept-bloc (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence job that validates dashboard digest output format
  Verification: bash -n cadence/validate-digest.sh
- [ ] Create a lib utility for parsing digest JSON into structured fields
  Verification: python3 -c "import json; json.load(open('lib/digest-parser.py'))"
- [ ] Add a test case that exercises the digest parser with sample data
  Verification: make test
- [ ] Update cadence/validate-digest.sh to use the new lib parser
  Verification: bash -n cadence/validate-digest.sh
- [ ] Add a dashboard integration test that runs the full digest pipeline
  Verification: make test
- [ ] Document the new cadence job in cadence/README.md
  Verification: grep -q "validate-digest" cadence/README.md
