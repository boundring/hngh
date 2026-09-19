<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-19 - dev-fail-20260917-What-is-the-absolute-path- (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the cadence-preflight research line: an additive, stdlib-only validator so malformed job cadence specs fail before scheduling rather than at runtime. This keeps every change plain-commit landable in hngh-automation and gated by its make test.

## Steps

- [ ] Add `lib/cadence_spec.py`, a stdlib-only module exposing `validate(spec)` that checks schedule/window/retry fields and returns error strings, with a `__main__` self-test that exits 0 on the bundled fixtures.
  Verification: python3 lib/cadence_spec.py

- [ ] Add `scripts/cadence_preflight.sh` that iterates `jobs/*.yaml`, feeds each `cadence:` block to the validator, and exits non-zero on any error.
  Verification: bash -n scripts/cadence_preflight.sh

- [ ] Add a valid sample spec at `jobs/cadence_sample.yaml` with a `cadence:` block (schedule, window, retry) that
