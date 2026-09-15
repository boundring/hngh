<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-15 - dev-fail-20260914-What-is-the-current-maximu (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a schema validation script that enforces distinct `parse_pass` and `operator_override` fields in plan-acceptance artifacts.
  Verification: python3 scripts/validate_acceptance_artifact.py
- [ ] Implement a state model patch in the beat script to explicitly distinguish "timeout-complete" from "in-progress" markers.
  Verification: bash -n scripts/beat_state_model.sh
- [ ] Create a test suite asserting the distinction between clean-complete and timeout-complete states.
  Verification: make test
- [ ] Add a probe script to capture failing target, trailing stderr, and /proc metrics at make failure time.
  Verification: bash -n scripts/capture_make_failure.sh
