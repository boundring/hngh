<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-14 - dev-fail-20260913-Does-lib-automation-py-inv (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the adopted research lines on the `lib/automation.py` ↔ `bin/hngh` subprocess boundary and corrected CLI contract conformance by adding hermetic integration tests and a cadence beat for ongoing boundary verification, closing the coverage gap where only a deferred overnight harness existed.

## Steps

- [ ] Add `tests/test_automation_subprocess_seam.py`, a stdlib-only Python test asserting that `lib/automation.py` resolves the hngh binary through an environment-overridable path variable (subprocess seam) rather than a direct module import.
  Verification: python3 tests/test_automation_subprocess_seam.py

- [ ] Add `scripts/check-hngh-cli-contract.sh`, a bash script that invokes the hngh binary with the post-2026-08-25 corrected argument shape and asserts exit code 0, confirming downstream conformance to the upstream guardrail fix.
  Verification: bash scripts/check-hngh-cli-contract.sh

- [ ] Add `cadence/hour/34-boundary-check.sh`, a cadence beat that runs the boundary test on schedule and records wall time separately for the mechanical leg (file reads, state append) and the model leg to distinguish expected latency from defects.
  Verification: bash -n cadence/hour/34-boundary-check.sh

- [ ] Create `digest/RESEARCH-BEAT-20260913-fail-20260913-Are-there-any-existing-integration-tests.md` documenting that synchronous boundary test coverage is now in place, referencing the Hngh Test Boundary concept (SRC-2026-08-24-029) and the subprocess seam pattern.
  Verification: grep -q 'subprocess-seam' digest/RESEARCH-BEAT-20260913-fail-20260913-Are-there-any-existing-integration-tests.md
