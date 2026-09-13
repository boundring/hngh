<!-- plan: status=superseded risk=normal accepted=2026-09-08T04:32:07Z routed-from=dash-selfreview:summary  cause=missing-design disposed=2026-09-12T14:13:41Z reason=design line landed: docs/research/2026-09-12-dash-selfreview-ledger-sync-skew.md; fix re-cut into plan 2026-09-12-routed-dash-selfreview-ledger-sync-skew -->
# 2026-09-08 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:summary`
at 2026-09-08T02:43:12Z. Alert text: [dash-selfreview] summary: 7 findings (7 unacceptable-now, 0 acceptable-for-now)

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-08T03:00:34Z re-occurred (dedup window expired)

- 2026-09-12T11:15:00Z occurrence examined read-only (session
  2026-09-08-routed-dash-selfreview-summary dream beat). Staged, not
  executed: `report-queue --prune` is a wrong cut of this finding.
  Evidence (all measured 2026-09-12T11:03Z, brickertop tree, no
  mutation):
  - Local drift = 25 (rows=2363 via `scripts/report-queue --json` vs
    2388 bodies), under LEDGER_DRIFT_MAX=50: the check itself passes
    locally right now.
  - Decomposition of the 25: 14 `prune-archive-2026-08-27..09-12`
    archive appendix files (benign, never linked from the table) + 11
    orphan alert/progress bodies from 2026-08-26..09-03 whose rows were
    already pruned earlier. Zero rows point at missing bodies locally,
    so `--prune` locally is a no-op by construction.
  - Root cause confirmed as cross-machine tree skew, not accumulated
    orphans: the 2026-09-10T19:00Z ledger-sanity row shows drift 1811
    (rows=259 vs bodies=2070) and the 2026-09-12 morning digest shows
    drift 1761 (rows=485) — both row counts far below this tree's 2363
    — while the hourly machine ledger-sync commits keep appending matched
    row+body pairs (e.g. c1df050, d8c3578 on 2026-09-12). The other
    machine reconciles rows and bodies on different pull lags, so the
    delta flaps 25 -> 1761 with no local corruption. Pruning one side's
    local state without its sync commit landing re-creates the finding
    next tick (the recorded 30-kernel-ledger-sync skew history).
  - Last ledger-sanity firing in this tree: 2026-09-10T19:00:18Z (>24h
    ago); the 2026-09-12 re-fire text came from the other machine's
    queue via the digest.
  Remaining loop (needs a design line, not a prune verb): make the
  ledger/body pair atomic AND push-atomic across machines — e.g.
  machine ledger-sync committing reports.md and report-bodies in the
  same commit (it already does) plus a deck-side kernel `git pull`
  before its dashboard-self-review run, or a skew-aware
  dash-selfreview check that resolves ledger vs bodies by commit age
  rather than raw counts. Proposed plan slug:
  2026-09-12-routed-dash-selfreview-ledger-sync-skew. Blocker recorded
  per plan autonomy rule; step left unchecked.

- 2026-09-12T14:13:26Z occurrence executed (session
  2026-09-08-routed-dash-selfreview-summary executor beat). Design line
  landed: docs/research/2026-09-12-dash-selfreview-ledger-sync-skew.md;
  fix re-cut into plan
  2026-09-12-routed-dash-selfreview-ledger-sync-skew (created accepted,
  step unchecked). Drift re-measured read-only: rows=2383, bodies=2408,
  drift=-25 — under LEDGER_DRIFT_MAX=50, the finding's own check passes
  locally; no local repair exists. This plan is disposed superseded
  (cause missing-design).
- 2026-09-12T23:00:49Z re-occurred (dedup window expired)
- 2026-09-13T00:00:13Z re-occurred (dedup window expired)
- 2026-09-13T01:00:49Z re-occurred (dedup window expired)
- 2026-09-13T02:00:49Z re-occurred (dedup window expired)
