<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-14 - dev-fail-20260913-Does-lib-automation-py-inv (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements research line fail-20260913-Does-lib-automation-py-invoke-bin-hngh-v by adding a hermetic subprocess-seam test that pins the `lib/automation.py` → `bin/hngh` invocation contract (env-overridable binary path, no direct module import) and gates it via `make test`.

## Steps

- [ ] Add `tests/test_automation_subprocess_seam.py` asserting `lib.automation` resolves the hngh binary through an env var (e.g. `HNHG_BIN`) and invokes it via `subprocess`, not a direct `import bin.hngh`.
  Verification: python3 tests/test_automation_subprocess_seam.py

- [ ] Add a stub fixture `tests/fixtures/fake-hngh` (a minimal bash script that echoes its argv) so the seam test can point `HNHG_BIN` at it without touching real credentials or kernel paths.
  Verification: bash -n tests/fixtures/fake-hngh

- [ ] Extend `lib/automation.py` invocation path to honor the `HNHG_BIN` env override (falling back to default `bin/hngh`) so the seam is testable in-repo; keep behavior identical when unset.
  Verification: make test

- [ ] Add a regression guard `tests/test_no_direct_import_of_bin_hngh.py` that fails if `lib/automation.py` contains a direct module import of `bin.hngh`.
  Verification: python3 tests/test_no_direct_import_of_bin_hngh.py

- [ ] Wire the new seam test into the existing suite so `make test` runs it (update the test discovery list or add to `tests/` auto-discovery) and confirm a clean pass.
  Verification: make test
