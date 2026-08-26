# Fast-test cache: full-gate `make test` cached per identical inputs

**Date:** 2026-08-26
**Change:** `scripts/verify-candidate.py`

## Context

`scripts/verify-candidate.py` runs `make test` unconditionally in `main()`
(the full-gate). Profiling (cProfile + timing): that single call is ~33s, and
ceremony-drive invokes verify-candidate ~5× per ceremony (gather, prepare
issue-cert/check, commit issue-cert/check, push) — ~3.5 min of repeated
identical full-gate runs. This cached the result keyed to identical inputs.

## Change

The unconditional `run_command(["make","test"])` is replaced by a cached
fast-test step that fails closed:

- **Cache key** (computed BEFORE the test): `f"{base_revision}|{candidate_hash}|{normalized_porcelain}"`
  where `normalized_porcelain` is the exact `git status --porcelain=v1
  --untracked-files=all` output the run already produced. Any change to base
  revision, candidate content, or full working-tree state invalidates.
- **Marker file:** `${TMPDIR:-/tmp}/hngh-fasttest-<repo>-<sha256>.ok`
  (`repo` = basename of cwd; `<sha256>` = hex digest of the key string, so the
  porcelain/newlines never appear in the filename). Content: `base-revision`,
  `candidate-hash`, `rc`, `duration`.
- **Hit:** marker exists and parses and `rc == 0` and stored `candidate-hash`
  matches → skip `make test`, still report `fast-test: passed`, and add the
  `(cached)` note only in the trace line (`trace: fast-test passed (cached)`).
  The output line `fast-test: passed` is kept verbatim (tests/scripts/
  test-verify-candidate.py asserts the substring).
- **Miss / unreadable / corrupt / rc != 0:** run the real `make test` and
  write/refresh the marker. A cached FAILURE (`rc != 0`) is stored but never
  satisfies the pass gate — only `rc == 0` passes (fail closed).

The candidate content hash is now computed before the gate (moved above it);
it was previously computed after.

## Evidence

Self-contained probe: manifest naming `scripts/verify-candidate.py`, run
twice, identical working tree.

| run | elapsed | exit | result |
|-----|---------|------|--------|
| 1 (cold, real `make test`) | 31.58 s | 0 | `:passed` |
| 2 (warm, second identical) | 0.10 s | 0 | `:passed`, `fast-test: passed (cached)` |

Both runs identical output (`fast-test: passed` / `:passed`). Marker written:
`/tmp/hngh-fasttest-hngh-184cc19961d4c4d854ea68303789625eafc406f554c4921f8da7d82d13699a82.ok`
(`rc: 0`).

## Gate not weakened

The mutation executor (ceremony-drive's `hngh_mutation_check`) re-verifies
tree-state and file hashes freshly at each mutation action
(issue-cert/commit/push) against its own admitted evidence. This optimization
only caches the FULL-GATE `make test` result keyed to identical inputs; any
cache miss/unreadable/corrupt marker falls back to the real test.

## Tests

`python3 tests/scripts/test-verify-candidate.py` → 77 checks passed. The
harness asserts `"fast-test: passed"` as a substring, which remains true on
cache hits. Full gate: `make test` green (recorded below).