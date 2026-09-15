<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-15 - dev-fail-20260914-What-is-the-current-maximu (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements research line fail-20260915-Does-the-beat-script-s-state-model-disti by adding a stored completion-token state model to hngh-automation so timeout-complete is distinguishable from in-progress.

## Steps

- [ ] Add `lib/beat_state.py` with stdlib-only constants for `in_progress` and `timeout_complete`, a classifier, and a self-test that exits 0.
  Verification: python3 lib/beat_state.py
- [ ] Add `scripts/beat-state-probe.sh` that reads a status file path and prints the classified state token using `lib/beat_state.py`.
  Verification: bash -n scripts/beat-state-probe.sh
- [ ] Add `tests/test-beat-state.sh` asserting missing marker classifies as in-progress and explicit timeout-complete marker classifies as timeout-complete.
  Verification: make test
- [ ] Add `cadence/beat-state.md` documenting that completion is stored at finalization, not derived from elapsed time.
  Verification: grep -q "timeout-complete" cadence/beat-state.md
