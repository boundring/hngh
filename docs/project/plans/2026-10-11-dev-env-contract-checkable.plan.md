<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-11 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the hngh-cadence research line by introducing a dry-run validation pipeline for job definitions and cadence manifests.

## Steps

- [ ] Create `scripts/dry_run.sh` to validate job definition syntax before execution
  Verification: bash -n scripts/dry_run.sh
- [ ] Create `cadence/manifest.json` defining the cadence schedule structure
  Verification: python3 -c "import json; json.load(open('cadence/manifest.json'))"
- [ ] Create `lib/cadence_utils.py` with helper functions for schedule parsing
  Verification: python3 -c "import ast; ast.parse(open('lib/cadence_utils.py').read())"
- [ ] Create `tests/test_cadence.sh` to exercise the dry-run and manifest validation
  Verification: bash -n tests/test_cadence.sh
- [ ] Create `dashboard/summary.md` template for cadence execution reports
  Verification: grep -q 'summary' dashboard/summary.md
