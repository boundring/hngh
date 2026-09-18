<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z -->
# 2026-09-17 - dev-fail-20260916-Which-specific-SLSA-level- (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the cadence-interval normalization research line by adding a stdlib-only interval parser under `lib/`, a cadence manifest validator, and wiring both into the job dry-run path so malformed cadence strings fail fast before any job is enqueued.

## Steps

- [ ] Add lib/cadence.py exposing parse_interval(text) -> int seconds using only the Python standard library, with an assert-based self-check under `if __name__ == "__main__"`.
  Verification: python3 lib/cadence.py
- [ ] Add tests/cadence_test.py with stdlib-only asserts for "5m", "1h", "90s" and rejection of a malformed token like "x".
  Verification: python3 tests/cadence_test.py
- [ ] Add cadence/validate.py that loads a cadence manifest (list of {name, interval}) and exits non-zero on any unparseable interval, defaulting to an inline sample when no path is given.
  Verification: python3 cadence/validate.py
- [ ] Add jobs/dryrun.sh that shells out to `python3 cadence/validate.py` and aborts the enqueue dry-run on failure, keeping the script bash-checkable.
  Verification: bash -n jobs/dryrun.sh
- [ ] Land the change as a plain commit gated by the repo suite so cadence strings fail fast before any job is enqueued.
  Verification: make test
