<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-13 - dev-fail-20260913-Does-lib-automation-py-inv (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements research line `fail-20260913-Are-there-any-existing-integration-tests` by converting the overnight-harness-only boundary coverage into synchronous, pre-merge test gates for the `lib/automation.py` ↔ `bin/hngh` subprocess seam and its post-2026-08-25 CLI contract, with a model-leg timeout guard on the cadence beat.

## Steps

- [ ] Create `tests/test_automation_subprocess_seam.py` (stdlib-only) that sets an env-overridable binary-path variable, imports `lib/automation.py`, and asserts the module invokes `bin/hngh` via `subprocess.run` or `subprocess.Popen` rather than a direct `import bin.hngh`.
  Verification: python3 tests/test_automation_subprocess_seam.py

- [ ] Create `tests/test_cli_contract_conformance.py` (stdlib-only) that feeds the corrected post-2026-08-25 argument vector to the automation entry point and asserts exit code 0 with no guardrail error string on stderr.
  Verification: python3 tests/test_cli_contract_conformance.py

- [ ] Edit `cadence/hour/33-research-beat.sh` to wrap the model-leg inference call in a wall-time timeout cap (configurable via env var, default 120 s) so that on breach the script writes an observable `TIMEOUT_BREACH` state line to the beat log and exits non-zero.
  Verification: bash -n cadence/hour/33-research-beat.sh

- [ ] Create `scripts/boundary_smoke.sh` that runs the subprocess-seam test and the CLI contract test in sequence, printing a single `PASS` or `FAIL` digest line to stdout for overnight-harness consumption.
  Verification: bash scripts/boundary_smoke.sh
