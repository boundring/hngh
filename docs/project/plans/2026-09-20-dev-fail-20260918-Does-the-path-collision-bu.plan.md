<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-20 - dev-fail-20260918-Does-the-path-collision-bu (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the cadence-driven digest automation research line by wiring a nightly digest job through the existing schedule and test harness in hngh-automation. It adds no provider, credential, or kernel surface—only plain job, cadence, library, and test files gated by `make test`.

## Steps

- [ ] Create `jobs/nightly_digest.sh` that assembles a daily digest payload from recent run logs and exits 0 on success.
  Verification: bash -n jobs/nightly_digest.sh
- [ ] Register the nightly digest job in `cadence/schedule.yaml` with a 02:00 UTC entry pointing to `jobs/nightly_digest.sh`.
  Verification: grep -q "nightly_digest" cadence/schedule.yaml
- [ ] Add `lib/digest_format.py` containing stdlib-only helper functions (`format_record`, `summarize`) used by the digest job.
  Verification: python3 lib/digest_format.py
- [ ] Add `tests/test_digest_job.sh` that invokes `jobs/nightly_digest.sh` in dry-run mode and asserts exit code 0.
  Verification: bash tests/test_digest_job.sh
