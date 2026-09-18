<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z -->
# 2026-09-17 - dev-fail-20260916-Does-the-harness-verificat (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements research line `fail-20260916-Does-the-harness-verification-script-hng` by materializing the `Storage=persistent` harness check as a dedicated, testable script and codifying the C1–C3 redundancy conditions so future audit decisions rest on documented criteria rather than an unverified premise.

## Steps

- [ ] Create `scripts/verify-storage-persistent.sh` that accepts a single file-path argument, runs `grep -qF 'Storage=persistent' "$1"`, and exits 0 on match / 1 on miss / 2 on usage error.
  Verification: `bash -n scripts/verify-storage-persistent.sh`

- [ ] Add `tests/test-verify-storage-persistent.sh` containing two inline fixtures (one with the token, one without) that invoke the script and assert the expected exit codes via `set -e` and explicit comparisons.
  Verification: `make test`

- [ ] Create `lib/redundancy-conditions.md` stating C1 (existence + defect-class fidelity), C2 (gate liveness — the check runs in every harness invocation), and C3 (coverage completeness) as necessary-and-sufficient conditions for declaring an external audit redundant.
  Verification: `grep -q 'C2' lib/reduancy-conditions.md`

- [ ] Add `cadence/storage-persistent-check.sh` that resolves the kernel unit-file path from an environment variable and delegates to `scripts/verify-storage-persistent.sh`, so the check is wired into the periodic harness gate without hard-coding a kernel-repo path.
  Verification: `bash -n cadence/storage-persistent-check.sh`
