<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-17 - dev-fail-20260916-Is-there-a-verified-file-p (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the fail-20260916 research line by adding a deterministic, gate-integrated verification step to hngh-automation that checks for the presence of `Storage=persistent` in a designated configuration source file, ensuring the audit is reproducible and not redundant with existing harness checks.

## Steps

- [ ] Create a placeholder journald configuration template file at `lib/journald.conf.template` containing the line `Storage=persistent`.
  Verification: `grep -qF 'Storage=persistent' lib/journald.conf.template && echo "PASS"`
- [ ] Add a new verification script `scripts/verify-journald-storage.sh` that runs `LC_ALL=C grep -F -- 'Storage=persistent' lib/journald.conf.template` and exits with status 0 if found.
  Verification: `bash scripts/verify-journald-storage.sh && echo "PASS"`
- [ ] Update the main test suite entry point (e.g., `tests/run_tests.sh` or equivalent) to invoke `scripts/verify-journald-storage.sh`.
  Verification: `make test`
- [ ] Add a negative test case in `tests/test_journald_storage.sh` that verifies the script fails (exits non-zero) when the target file does not contain `Storage=persistent`.
  Verification: `bash tests/test_journald_storage.sh && echo "PASS"`
