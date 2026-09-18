<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z -->
# 2026-09-17 - dev-fail-20260917-Does-the-in-toto-v1-schema (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the adopted cadence-window determinism research line for hngh-automation. It adds a stdlib-only windowing helper, unit tests, and report/digest emitters so digest windows can be scheduled without provider or credential changes.

## Steps

- [ ] Add `lib/cadence_window.py` as a stdlib-only module exposing pure `window_start(ts, step)` and `window_end(ts, step)` functions with floor-to-step semantics.
  Verification: make test
- [ ] Add `tests/test_cadence_window.py` using stdlib `unittest` to assert boundary behavior for zero, exact multiples, and negative timestamps.
  Verification: python3 tests/test_cadence_window.py
- [ ] Add `scripts/cadence_report.py` that imports the helper and prints one deterministic line per window for a default range when run with no arguments.
  Verification: python3 scripts/cadence_report.py
- [ ] Add `digest/cadence_digest.py` that consumes the helper to emit plain-text digest entries containing start, end, and window count; no network access or credentials.
  Verification: python3 digest/cadence_digest.py
- [ ] Add `scripts/run_cadence.sh` as a thin shell wrapper that invokes the report script and pipes its output into the digest emitter for local runs.
  Verification: bash -n scripts/run_cadence.sh
