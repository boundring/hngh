<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-17 - dev-fail-20260916-Are-there-any-captured-bui (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line regarding the verification of `Storage=persistent` configuration templates and build log artifacts, establishing a deterministic probe script to settle the unresolved file-content questions.

## Steps

- [ ] Create `scripts/probe_storage_persistent.sh` containing a `grep -F -- 'Storage=persistent'` check against the target observation file path.
  Verification: bash -n scripts/probe_storage_persistent.sh

- [ ] Add a test fixture file under `tests/fixtures/` that contains the literal string `Storage=persistent` to validate the probe script's positive match logic.
  Verification: grep -qF 'Storage=persistent' tests/fixtures/storage_persistent_fixture.conf

- [ ] Implement a recursive make error log parser in `lib/log_parser.py` that identifies `make[2]:` or higher recursion levels in build logs.
  Verification: python3 lib/log_parser.py --help

- [ ] Create `tests/test_log_parser.py` to verify the parser correctly distinguishes single-level failures from recursive make errors.
  Verification: python3 tests/test_log_parser.py

- [ ] Update `digest/RESEARCH-BEAT-latest-fail-20260916-Are-there-any-captured-build-logs-from-h.md` to record the probe script path and verification status.
  Verification: grep -q "scripts/probe_storage_persistent.sh" digest/RESEARCH-BEAT-latest-fail-20260916-Are-there-any-captured-build-logs-from-h.md
