<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-16 - dev-fail-20260917-overnight-plan-accept-bloc (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new job script under jobs/ that validates input data structure before processing
  Verification: bash -n jobs/validate-input.sh

- [ ] Create a corresponding test file under tests/ that exercises the validation logic
  Verification: make test

- [ ] Add a verification script under scripts/ that checks job output format compliance
  Verification: bash scripts/check-output-format.sh

- [ ] Update cadence/ configuration to register the new validation job in the pipeline
  Verification: grep -q 'validate-input' cadence/pipeline.yaml

- [ ] Add a dashboard snippet under dashboard/ that displays validation pass/fail status
  Verification: bash -n dashboard/validation-status.js

- [ ] Create a digest template under digest/ that formats validation results for downstream consumers
  Verification: grep -q 'validation' digest/template.md
