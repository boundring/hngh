<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-16 - dev-fail-20260915-Which-specific-environment (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line `fail-20260915-Which-specific-environment-variables-or-` by establishing a hermetic subprocess-stub seam in hngh-automation to isolate external binary dependencies during testing. It defines specific environment variables and stub binary paths that allow tests to run without requiring real system services or network access, directly addressing the unresolved question of what constitutes the "subprocess-stub-seam" for hermetic testing.

## Steps

- [ ] Create a `lib/stub-env.sh` script that exports standard hermetic test environment variables (e.g., `HNNGH_TEST_STUB=1`, `PATH=/tmp/hngh-stubs:$PATH`) to signal stub mode to automation scripts.
  Verification: bash -n lib/stub-env.sh

- [ ] Create a `scripts/install-stubs.sh` script that generates dummy executable files in a temporary directory (e.g., `/tmp/hngh-stubs/ssh`, `/tmp/hngh-stubs/curl`) that exit with code 0 and print "STUB" to stdout.
  Verification: bash -n scripts/install-stubs.sh

- [ ] Add a test case in `tests/test_stub_seam.sh` that sources `lib/stub-env.sh`, runs `scripts/install-stubs.sh`, and verifies that calling `ssh` via the modified PATH returns "STUB" instead of executing real SSH.
  Verification: bash tests/test_stub_seam.sh

- [ ] Update the main test runner or Makefile integration point in `tests/` to ensure `make test` includes execution of `tests/test_stub_seam.sh`.
  Verification: make test

- [ ] Document the defined environment variables and stub binary paths in a new file `digest/SUBPROCESS-STUB-SEAM.md` to resolve the research question by explicitly naming the seam components.
  Verification: grep -q "HNNGH_TEST_STUB" digest/SUBPROCESS-STUB-SEAM.md
