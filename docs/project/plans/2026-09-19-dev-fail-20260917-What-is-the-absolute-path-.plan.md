<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-19 - dev-fail-20260917-What-is-the-absolute-path- (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the adopted research line on local digest-cadence observability for hngh-automation by adding small stdlib and shell checks that stay inside automation paths.

## Steps

- [ ] Add scripts/hngh_digest_status.py that prints a stable one-line digest status using only Python stdlib and exits 0.
  Verification: python3 scripts/hngh_digest_status.py
- [ ] Add jobs/hngh-digest-status.sh that invokes the status script with set -euo pipefail and propagates its exit code.
  Verification: bash -n jobs/hngh-digest-status.sh
- [ ] Add cadence/hngh-digest-check.md describing the local digest status check as a normal-risk cadence item.
  Verification: grep -q "hngh-digest-status" cadence/hngh-digest-check.md
- [ ] Add tests/hngh_digest_status_test.py that runs the status script via subprocess and asserts exit code 0 plus a digest-bearing output line.
  Verification: python3 tests/hngh_digest_status_test.py
