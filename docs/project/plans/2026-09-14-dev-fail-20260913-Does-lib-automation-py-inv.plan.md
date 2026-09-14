<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-14 - dev-fail-20260913-Does-lib-automation-py-inv (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the `fail-20260913-Does-lib-automation-py-invoke-bin-hngh-v` research line (with supporting boundary-coverage and guardrail-contract findings) by adding hermetic subprocess-seam verification, dedicated boundary integration test coverage, a CLI contract conformance check, and a model-leg wall-time guard to the cadence beat.

## Steps

- [ ] Create tests/test_subprocess_seam.sh that greps lib/automation.py for `subprocess` usage and asserts an env-overridable binary-path seam exists (no direct module import of bin/hngh).
  Verification: bash -n tests/test_subprocess_seam.sh
- [ ] Create tests/test_boundary_integration.sh that exercises the lib/automation.py → bin/hngh process boundary using a stub binary on PATH, matching the hermetic-seam pattern from prior material.
  Verification: bash -n tests/test_boundary_integration.sh
- [ ] Create scripts/check_cli_contract.sh that invokes lib/automation.py against a corrected post-2026-08-25 CLI contract fixture and asserts clean exit with no guardrail regression.
  Verification: bash -n scripts/check_cli_contract.sh
- [ ] Edit cadence/hour/33-research-beat.sh to wrap the model-leg call in a wall-time guard that logs elapsed seconds and caps execution at a configurable threshold before appending state.
  Verification: bash -n cadence/hour/33-research-beat.sh
