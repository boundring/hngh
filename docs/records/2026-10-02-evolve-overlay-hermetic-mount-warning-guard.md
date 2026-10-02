# 2026-10-02 — evolve-dashboard-style: hermetic test mount + warning-collision guard

## Summary

Two defects in the dashboard style-evolution loop, one root cause each,
landed as a single certificate-bound candidate.

1. **Test harness raced the subhour cadence writer and could strand test
   state on the live mount.** `tests/scripts/test-evolve-dashboard-style.py`
   snapshotted `docs/design/ui-evolve/current-overlay.json` at module
   import and restored it in `tearDown`. Any mount the cadence writer
   (`automation/cadence/subhour/01-evolve-ui.sh` ->
   `scripts/evolve-dashboard-style`) landed between import and tearDown
   was silently overwritten with the stale snapshot (lost update); an
   interrupted test run left `preset=ocean seed 5` test content live.
   The mount path is now env-overridable (`EVOLVE_OVERLAY`,
   `scripts/evolve-dashboard-style` OVERLAY definition); the test
   redirects every run to a throwaway temp path, the snapshot/restore
   machinery for the overlay is deleted, and the live mount is never
   touched (byte-identical before/after a full suite run, sha256
   verified).

2. **Swap mutations could mount a palette whose warning color equals
   the success/primary color.** `PRESETS["hngh"]` shares
   `#5af78e` across primary/accent/success; `mutate` flips a swap
   25% of the time over all `COLOR_FIELDS`, so swapping warning with
   any of those put the success green into warning while grading only
   checked warning-vs-error distance — the colliding palette scored
   well and mounted; `scripts/dashboard-tui` rendered warnings in
   green. `_swap_pair` now refuses any swap whose result would leave
   `warning` equal to `primary`, `success`, or `error` (channel
   shifts cannot collide, delta is +/-8; swaps were the only vector).
   Failing-first: `test_warning_never_collides_with_signal_colors`
   swept every preset x 200 seeds and failed at `hngh seed 59`
   (`#5af78e` in warning) before the guard; passes after.

## Non-changes

- `gen` remains a batch-local candidate index (1..gens), non-monotone
  by design (docs/records/2026-08-26-evolve-dashboard-style.md); the
  "gen oscillates 1-2" review finding is a semantics mismatch, not a
  defect, and stays test-pinned (`test_self_grade_writes_ledger_and_mount`).

## Verification

- `python3 tests/scripts/test-evolve-dashboard-style.py`: 6/6 pass;
  live overlay sha256 unchanged across the run.
- Kernel gate `make test`: exit 0, 2957 checks passed.
- Committed through the dogfood ceremony loop.
