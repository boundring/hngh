<!-- plan: status=accepted risk=normal accepted=2026-09-19T19:04:00Z -->
# 2026-09-18 - dev-fail-20260917-Does-the-Sigstore-policy-e (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements research line R3 (deterministic digest + cadence-gated release validation) by adding a stdlib-only digest helper, an emit script, and declarative job/cadence wiring that stay entirely inside hngh-automation and are gated by its `make test`.

## Steps

- [ ] Add `lib/digest.py`, a stdlib-only module exposing `compute_digest(paths) -> str` (SHA-256 over sorted file bytes plus a combined digest) that runs a built-in fixture assertion when executed directly.
  Verification: python3 lib/digest.py
- [ ] Add `scripts/emit-digest.sh` that calls `python3 lib/digest.py` over a declared input set and writes `digest/manifest.json` containing per-file hashes and the combined digest.
  Verification: bash -n scripts/emit-digest.sh
- [ ] Add `jobs/digest-check.yml` declaring a job that runs `scripts/emit-digest.sh` and fails when the combined digest is absent, using only declarative fields (no provider or credential configuration).
  Verification: grep -q "scripts/emit-digest.sh" jobs/digest-check.yml
- [ ] Add `cadence/digest.yml` scheduling the `digest-check` job on a fixed cadence with declarative fields only (no systemd unit lifecycle).
  Verification: grep -q "digest-check" cadence/digest.yml
- [ ] Add `tests/test_digest.py`, a stdlib `unittest` module with a runnable main that asserts `compute_digest` is deterministic across two runs and matches a hardcoded fixture.
  Verification: python3 tests/test_digest.py
