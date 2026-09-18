<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z -->
# 2026-09-17 - dev-fail-20260916-Are-there-any-captured-bui (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the research line concerning the verification of `Storage=persistent` configuration strings and recursive make error logs by adding static content probes to the automation harness.
## Steps

- [ ] Create a bash script in scripts/ that greps for the literal string 'Storage=persistent' within designated configuration files.
  Verification: bash -n scripts/check_storage_persistent.sh

- [ ] Add a test case in tests/ that asserts the exit status of the new grep script matches expected values for known fixture files.
  Verification: make test

- [ ] Create a log parser utility in lib/ that identifies recursive make error patterns (make[N] with N >= 2) from text input.
  Verification: python3 -c "import sys; sys.path.insert(0, 'lib'); import log_parser"

- [ ] Add a unit test in tests/ to verify the log parser correctly distinguishes between single-level and recursive make errors.
  Verification: make test

- [ ] Update the dashboard configuration to include a new metric for tracking the presence of persistent storage flags in CI artifacts.
  Verification: grep -q "persistent_storage" dashboard/config.json
