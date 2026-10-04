# 2026-10-04 — Parallel gate runner

## What landed

- `automation/scripts/test-parallel.sh` — runs the automation gate suites
  concurrently. Suite list is extracted from `make -n test` (the Makefile
  recipe stays the single source of truth; the runner never duplicates it),
  deduplicated, split into per-suite `.cmd` files, and executed with
  `xargs -n1 -P "$JOBS"`. Each suite gets its own log plus a `.res` record
  (rc, wall seconds, command). Summary prints in recipe order with
  per-suite timing and the failing log tail on failure.
- `automation/Makefile` — new `test-parallel` target
  (`GATE_JOBS` knob, default nproc capped at 8) and removal of a duplicate
  `bash tests/test-credential-health-argv.sh` recipe line the runner
  exposed (raw recipe had 183 entries; 182 unique suites).

## Why

Operator directive (2026-10-04): the sequential gate wait (~300–466s) is
too long; gate-internal processes should be parallelized and optimized.
The parallel runner is additive: `make test` stays the canonical
sequential gate (deterministic, shared-state safe); `make test-parallel`
is the fast runner. Measured: `GATE-PARALLEL-RC=0 suites=182 wall=46s
jobs=8` vs ~466s sequential.

## Design notes

- Dry-run safety mirror of `omarchy-boot-build.sh` does not apply here;
  suites are the same read-only-by-construction tests the sequential gate
  already runs. Exit code is nonzero iff any suite failed.
- Worker completion-order progress lines + recipe-order summary; a suite
  with no `.res` counts as FAIL, never silently skipped.
- Written to satisfy `scripts/lint-identifiers.sh` (line-oriented
  definition regex `^[[:space:]]*NAME=` and reference regex `$NAME` /
  `${NAME}`): scalar variables only, `SECONDS` builtin for wall time
  (ignored name), lowercase loop locals.

## Verification

- `bash -n` clean; 21/21 pre-existing suites untouched.
- Full parallel run green: 182 suites, 46s, jobs=8, including
  `lint-identifiers.sh` and `lint-home-paths.py` as suites.
- `make -n test | grep -c test-credential-health-argv` → 1 after dedupe.

## Lessons

- GNU `xargs` packs multiple arguments per worker by default; a worker
  that reads only `$1` silently processes its chunk head. Always pair
  `-P` with `-n1` for one-job-per-worker semantics.
- `lint-identifiers.sh` is line-oriented: `mapfile`/array assignments are
  invisible as definitions and `$((A-B))` is invisible as a reference —
  write shell the linter can see.
