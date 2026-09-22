# Rotate-queue driver audit — hngh-ays evidence pass (2026-09-22)

Target: `scripts/rotate-queue` (262 lines, sbcl --script), the second live
certificate-driven mutation lane flagged by hngh-ays
(gap-rotate-queue-driver). Read-only audit; live-run evidence from
`docs/project/queue.md` (10 `rotated` markers) — the driver HAS executed.

## What the lane is

Full rotation = queue-row-flip → real candidate evidence
(`hngh.adapters.run-gather:run-candidate-evidence`) → create-run +
admit-transport → model review on the content hash → propose under the
ten principles → verdict file → issue-cert → mutation-check, all executed
through `hngh.main:dispatch-command` (`scripts/rotate-queue:131-134`).
No authority beyond the kernel's own closed commands (verified :146-229);
the periodic schedule lives outside Hngh (header :13-15). Lane legitimacy:
CONFIRMED.

## Findings

1. **F1 (real, fail-open lead mutation):** `queue-row-flip`
   (`scripts/rotate-queue:50-73`) flips the queue row to `done` BEFORE
   evidence gather / review / propose. Any later refusal (exit 1 at
   review, propose, issue-cert, mutation-check) leaves `docs/project/queue.md`
   mutated on disk — a false done row the next session reads as truth.
   Un-committed (so not pushed), but unreverted: the failure contract
   ("refusal halts the rotation") holds only for the rotation, not the
   ledger. Fix shape (parked, certificate-lane if kernel-side; plain
   commit if driver-side): flip AFTER mutation-check success, or revert
   the flip on any non-zero exit.
2. **F2 (design-consistent, not a defect):** the reviewer's rendered
   verdict is written to a temp file (`:202-208`, `:keep t`, deleted
   after) and used as the operator-verdict input to issue-cert. This is
   the operator-flexibility dogfood lane (wake-mutation-lane record,
   2026-09-13 amendment) — the verdict IS the gate by design.
3. **F3 (route discipline, clean):** `--route=auto|local|remote` resolves
   via one bounded read-only probe (`scripts/rotate-queue:87-112`, calls
   `scripts/probe-model-route`); refusal exits 1 before any mutation.
4. **F4 (no revert path):** the driver is forward-only — no verb or
   argument un-rotates an item, and `scripts/hngh` exposes no revert
   wrapper call. Rotation recovery = manual queue.md surgery. Acceptable
   at current cadence; note for revoke-rotation (hngh-ays sibling).

## Disposition

- No kernel defect requiring ceremony: the defect is in the driver
  (`scripts/rotate-queue`, repo-root scripts surface = kernel code
  surface — driver fixes carry the ceremony label).
- F1 filed as residual on hngh-ays; fix is one hunk in `rotate()`
  (move `queue-row-flip` call after the `execute "commit"` success path,
  using the already-computed queue-file name).
- 10 historical rotated rows are legitimate (each rode a candidate
  commit; spot-check of commit style `hngh: candidate …` consistent).

Audit by machine:omp session 2026-09-22; sources read at HEAD a98aa105.
