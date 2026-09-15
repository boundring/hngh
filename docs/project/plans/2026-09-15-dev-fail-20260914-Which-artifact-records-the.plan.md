<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-15 - dev-fail-20260914-Which-artifact-records-the (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line `fail-20260915-Does-the-beat-script-s-state-model-disti` by establishing a structured, auditable state model in hngh-automation that explicitly distinguishes between clean-complete and timeout-complete markers, closing the gap where completion status was previously conflated or derived ambiguously.

## Steps

- [ ] Define a canonical state enum in `lib/state_model.sh` containing distinct tokens for `clean_complete` and `timeout_complete`.
  Verification: grep -q "timeout_complete" lib/state_model.sh && grep -q "clean_complete" lib/state_model.sh

- [ ] Implement a finalization function in `scripts/finalize_run.sh` that writes the resolved state token to a status file.
  Verification: bash -n scripts/finalize_run.sh

- [ ] Add a unit test in `tests/test_state_distinction.sh` asserting that timeout-complete does not resolve to clean-complete.
  Verification: bash tests/test_state_distinction.sh

- [ ] Update the reconciliation logic in `cadence/reconcile.sh` to treat `timeout_complete` as a non-terminal state requiring retry.
  Verification: grep -q "timeout_complete" cadence/reconcile.sh && grep -q "retry" cadence/reconcile.sh

- [ ] Integrate the new state model into the main automation entrypoint in `jobs/run_automation.sh`.
  Verification: make test
