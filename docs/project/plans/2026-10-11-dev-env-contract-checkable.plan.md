<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-11 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Create a plain-text manifest listing the three research lines adopted from ADOPTED findings: 'scheduling', 'throttling', and 'retry-budget'.
  Verification: grep -c "research-line\|schedule\|throttle\|retry" hngh-automation/digest/adopted-findings.txt

- [ ] Add a `cadence/synth-plan.yaml` entry mapping each research line to its corresponding automation job name under `jobs/`.
  Verification: python3 -c "import yaml; d=yaml.safe_load(open('hngh-automation/cadence/synth-plan.yaml')); print(list(d.keys()))"

- [ ] Implement a small `scripts/plan-mapper.sh` that reads the manifest and emits one line per job with its research-line tag.
  Verification: bash scripts/plan-mapper.sh | wc -l

- [ ] Add a unit test in `tests/test_plan_mapper.py` asserting that each emitted line contains exactly one of the three required tags.
  Verification: python3 tests/test_plan_mapper.py
