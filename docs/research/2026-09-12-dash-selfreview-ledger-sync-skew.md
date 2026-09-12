# 2026-09-12 — dash-selfreview ledger-sync skew (design line)

## Question

Why does the dashboard self-review ledger-sanity check keep firing drift
findings (ledger rows vs body files) when both the local tree and the check
itself are healthy, and what change makes the finding fire only on real
corruption?

## Evidence read

- automation/jobs/dashboard-self-review.py:46 sets `LEDGER_DRIFT_MAX = 50`;
  the check at :160-175 compares `len(report-queue --json reports[])` against
  a glob count of docs/project/report-bodies/*.md and files an
  unacceptable-now finding past the threshold. Findings land via
  `report-queue --add`, identity `dash-selfreview:<check>`, window 86400
  (:21-22).
- Live read-only measurement 2026-09-12T14:05Z, this tree: rows=2383,
  bodies=2408, drift=-25 — under the threshold. The finding's own check
  passes locally right now, so no local repair can satisfy the routed step.
- Cross-machine skew in the shared ledger (docs/project/reports.md and the
  morning digest): the 2026-09-10T19:00Z ledger-sanity row shows drift 1811
  (rows 259 vs bodies 2070); the 2026-09-12 morning digest shows drift 1761
  (rows 485). Both row counts sit far below this tree's 2363-2383.
- Meanwhile the hourly machine ledger-sync commits keep appending matched
  row+body pairs in single commits (e.g. c1df050, d8c3578, 4dd3d40 on
  2026-09-12). The other machine reconciles rows and bodies on different
  pull lags, so the delta flaps 25 -> 1761 with no local corruption.
- This tree's latest local dash-selfreview rows end 2026-09-11T22:00:49Z
  (dedup escalation); the 2026-09-12 re-fires arrived only through the other
  machine's digest.
- Prior cuts: plan 2026-09-11-routed-dash-selfreview-summary was disposed
  obsolete 2026-09-11T22:00:49Z (operator escalation stands); the 2026-09-08
  plan's 2026-09-12T11:15Z occurrence staged this diagnosis and rejected
  `report-queue --prune` — locally it is a no-op by construction (zero rows
  point at missing bodies here), and on the skewed machine it would delete
  rows or bodies to manufacture consistency, then re-fire next tick.

## Doctrine applied

- Self-watch findings classify themselves (two-tier vocabulary,
  unacceptable-now / acceptable-for-now). A check that files unacceptable-now
  because another machine's replication lags behind misclassifies a transient
  as an emergency; the two-tier vocabulary exists precisely for this split.
- Fail-closed stays intact: unknown or unexplained drift still refuses into
  unacceptable-now. Only an explained, windowed transient (bounded by the
  hourly ledger-sync cadence) is downgraded, never silently dropped.
- Commit authority split: the fix lives in automation/jobs/
  dashboard-self-review.py (automation surface — free-commit on automation
  `make test` green). Kernel scripts/report-queue and tests/scripts/
  test-report-queue.py are untouched, so no ceremony-bound kernel surface
  changes.

## Findings

1. Root cause is cross-machine tree skew, not accumulated orphans or local
   corruption. The delta flaps between 25 and 1761-1811 with zero rows
   pointing at missing bodies locally, while matched row+body pairs land in
   the same ledger-sync commits.
2. `report-queue --prune` is a wrong cut: locally a no-op, remotely a
   consistency-manufacturing delete that re-fires next tick.
3. The check is count-based and tree-local; it cannot distinguish
   replication lag from corruption. It needs a skew guard, not different
   numbers: a count past the threshold is a finding only when the local tree
   has had a fair chance to sync.

## Recommended next line

Make the ledger-sanity check skew-aware in
automation/jobs/dashboard-self-review.py, test-first on the automation
surface:

- When `abs(rows - bodies) > LEDGER_DRIFT_MAX`, measure tree freshness:
  age of the kernel repo HEAD (`git log -1 --format=%ct`).
- New tunable `LEDGER_SKEW_MAX_AGE` (default 7200s = two periods of the
  hourly ledger-sync) in the tunables block (:44-47).
- Fresh tree (HEAD age within the window) that still drifts past the
  threshold: unacceptable-now "stale skew — reconcile" (real corruption
  class, unchanged behavior).
- Stale tree (HEAD age beyond the window): acceptable-for-now "transient
  cross-machine sync skew (tree Ns behind; re-evaluated post-sync)".
- Named verification: a hermetic fixture test in automation/tests/ proving
  the three classes (fresh+drift -> unacceptable-now; stale+drift ->
  acceptable-for-now transient; fresh+clean -> silent) plus automation
  `make test` green.
- Operational mitigation, not the fix: a deck-side `git pull` before the
  self-review run narrows the skew window but cannot classify it.

Supersedes plan docs/project/plans/
2026-09-08-routed-dash-selfreview-summary.plan.md (disposed superseded,
cause missing-design, this doc names the design line). The implementation
lives in plan docs/project/plans/
2026-09-12-routed-dash-selfreview-ledger-sync-skew.plan.md.
