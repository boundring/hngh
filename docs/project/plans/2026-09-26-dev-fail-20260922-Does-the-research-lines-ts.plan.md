<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-26 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `cadence/validate_manifest.py` script that checks job manifest YAML files for required keys and structure
  Verification: python3 cadence/validate_manifest.py --check

- [ ] Add a `tests/test_validate_manifest.py` test that asserts the script exits 0 on valid manifests and non-zero on malformed ones
  Verification: python3 tests/test_validate_manifest.py

- [ ] Add a `jobs/manifest_template.yaml` example manifest that satisfies the validation script's required keys
  Verification: python3 cadence/validate_manifest.py jobs/manifest_template.yaml

- [ ] Add a `scripts/run_validation.sh` wrapper that invokes the Python validator and returns its exit code
  Verification: bash -n scripts/run_validation.sh && bash scripts/run_validation.sh

- [ ] Add a `tests/test_run_validation.sh` test that confirms the wrapper script exits 0 on a valid manifest path
  Verification: bash tests/test_run_validation.sh

- [ ] Run the full test suite to confirm no existing tests are broken by the new additions
  Verification: make test
