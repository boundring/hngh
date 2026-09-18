<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-18 - dev-fail-20260917-Does-the-Sigstore-policy-e (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the cadence job-run digest research line, turning raw cadence run records into a normalized, human-readable digest without touching providers, credentials, or any kernel surface. It lands as small, independently gated commits inside hngh-automation's jobs/, scripts/, lib/, tests/, dashboard/, and digest/ trees.

## Steps

- [ ] Add lib/digest_summarize.sh defining a pure summarize_run() that normalizes a cadence run (id, status, duration) into one digest line with no network or env reads.
  Verification: bash -n lib/digest_summarize.sh
- [ ] Extend scripts/build_digest.sh to source lib/digest_summarize.sh and write one record per run under digest/.
  Verification: bash -n scripts/build_digest.sh
- [ ] Add tests/test_digest_summarize.sh that feeds a fixed fixture through summarize_run() and asserts the exact expected digest line.
  Verification: bash tests/test_digest_summarize.sh
- [ ] Add dashboard/digest_table.html as a static table rendering the digest records with no secrets or external calls.
  Verification: grep -q 'class="digest-table"' dashboard/d
