<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-20 - dev-fail-20260918-Does-the-path-collision-bu (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the 'cadence retry-visibility' research line by surfacing attempt counts and last-failure timestamps in the operator digest. It stays inside lib/, tests/, digest/, and scripts/ and is gated by make test, avoiding credentials, systemd units, and kernel sources.

## Steps

- [ ] Add lib/cadence_record.py exposing normalize(record) that maps a cadence workflow execution record to {status, attempt_count, last_failure_ts} using only stdlib (json, datetime), with an __main__ block that asserts a sample record round-trips and exits 0.
  Verification: python3 lib/cadence_record.py
- [ ] Add tests/test_cadence_record.py covering normalize() for succeeded, failed-once, and retried records, and register it so the existing suite picks it up under make test.
  Verification: make test
- [ ] Extend digest/render.py to pull attempt_count and last_failure_ts from lib.cadence_record and append them to each job line, with an __main__ block that renders one sample record to stdout and exits 0.
  Verification: python3 digest/render.py
- [ ] Add scripts/refresh_digest.sh that invokes the digest renderer and writes dashboard/digest.json, guarded by set -euo pipefail so a bad render fails loudly.
  Verification: bash -n scripts/refresh_digest.sh
