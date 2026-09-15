<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-15 - dev-fail-20260914-Which-artifact-records-the (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line regarding the distinction between clean-complete and timeout-complete states in the beat script, specifically addressing the untested gap by adding explicit state markers and verification logic to hngh-automation.

## Steps

- [ ] Create `lib/state_markers.sh` defining distinct sentinel strings for "clean_complete" and "timeout_complete" states
  Verification: bash -n lib/state_markers.sh

- [ ] Add a test case in `tests/test_state_distinction.sh` that asserts the two state markers are not identical
  Verification: make test

- [ ] Update `scripts/beat_finalize.sh` to write the appropriate state marker based on exit conditions
  Verification: bash -n scripts/beat_finalize.sh

- [ ] Create `digest/STATE_DISTINCTION_NOTES.md` documenting the semantic difference between timeout and clean completion
  Verification: grep -q "timeout_complete" digest/STATE_DISTINCTION_NOTES.md
