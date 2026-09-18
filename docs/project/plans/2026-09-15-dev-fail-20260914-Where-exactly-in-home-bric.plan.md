<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z -->
# 2026-09-15 - dev-fail-20260914-Where-exactly-in-home-bric (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the research line on capturing failing target, trailing stderr, and /proc metrics at failure time in the make exit-code consumption point by adding a probe-first, schema-first gate wrapper under scripts/ that records structured failure artifacts without altering kernel build targets.

## Steps

- [ ] Add a shell helper `scripts/gate-capture.sh` that wraps a make invocation, captures `$?`, failing target name, trailing stderr lines, and `/proc/self/status` snapshot at failure time into a JSON artifact under `digest/`.
  Verification: bash -n scripts/gate-capture.sh

- [ ] Create a minimal test fixture `tests/fixtures/fake-make.sh` that simulates a make run with a known failing target and deterministic stderr output for hermetic testing.
  Verification: bash -n tests/fixtures/fake-make.sh

- [ ] Add a shell test `tests/test-gate-capture.sh` that invokes `scripts/gate-capture.sh` against the fake fixture, asserts the JSON artifact contains the failing target, trailing stderr, and /proc metrics fields, and exits non-zero on missing fields.
  Verification: bash tests/test-gate-capture.sh

- [ ] Extend the Makefile test entrypoint to include the new gate-capture test in its `test` target so `make test` runs it.
  Verification: make test

- [ ] Add a digest schema note `digest/SCHEMA-gate-failure-artifact.md` documenting the JSON fields (target, stderr_tail, proc_snapshot, timestamp) and the R2 distinction between parse_pass and operator_override signals.
  Verification: grep -q "parse_pass" digest/SCHEMA-gate-failure-artifact.md
