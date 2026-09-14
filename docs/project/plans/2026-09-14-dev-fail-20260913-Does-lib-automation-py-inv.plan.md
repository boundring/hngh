<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-14 - dev-fail-20260913-Does-lib-automation-py-inv (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the `lib/automation.py` ↔ `bin/hngh` boundary research lines by adding a hermetic subprocess-seam integration test and documenting the corrected CLI contract, ensuring the overnight harness's regression coverage is gated synchronously.

## Steps

- [ ] Create `tests/test_automation_subprocess_seam.py` that stubs the env-overridable binary path and asserts `lib/automation.py` invokes `bin/hngh` via `subprocess` rather than direct import.
  Verification: make test
- [ ] Add a guardrail regression case in `tests/test_cli_contract_guardrail.py` verifying `lib/automation.py` handles the post-2026-08-25 corrected CLI contract without raising on upstream kernel responses.
  Verification: make test
- [ ] Extend `cadence/hour/33-research-beat.sh` to emit a structured `wall_s` and `model_leg_s` breakdown so latency spikes are attributable to the inference call rather than I/O.
  Verification: bash -n cadence/hour/33-research-beat.sh
- [ ] Update `digest/RESEARCH-BEAT-fail-20260913-Are-there-any-existing-integration-tests.md` to record that the new synchronous test now blocks merges on the automation boundary.
  Verification: grep -q "synchronous gate" digest/RESEARCH-BEAT-fail-20260913-Are-there-any-existing-integration-tests.md
