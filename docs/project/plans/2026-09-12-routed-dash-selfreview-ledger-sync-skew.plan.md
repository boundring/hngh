<!-- plan: status=accepted risk=normal accepted=2026-09-12T14:13:26Z routed-from=dash-selfreview:summary -->
# 2026-09-12 — dash-selfreview ledger-sync skew (supersedes 2026-09-08-routed-dash-selfreview-summary)

Routed by hand from the staged diagnosis in the 2026-09-08 plan
(occurrence 2026-09-12T11:15Z) and the design line
docs/research/2026-09-12-dash-selfreview-ledger-sync-skew.md. Root cause is
cross-machine ledger/body pull skew, not local corruption: the finding's own
check passes on this tree (drift -25 at 2026-09-12T14:05Z), so no local
repair satisfies the old plan. The 2026-09-08 plan is disposed superseded,
cause missing-design; the 2026-09-11 sibling stays parked obsolete.

## Steps

- [ ] Make the ledger-sanity check skew-aware (tree-freshness guard) in
      automation/jobs/dashboard-self-review.py, test-first: new tunable
      LEDGER_SKEW_MAX_AGE (default 7200s); fresh tree + drift past
      LEDGER_DRIFT_MAX files unacceptable-now "stale skew — reconcile";
      stale tree + drift files acceptable-for-now transient sync skew.
      Verification: hermetic fixture test in automation/tests/ covering
      fresh+drift (unacceptable-now), stale+drift (acceptable-for-now
      transient), fresh+clean (silent); automation `make test` green.

## Occurrences

- 2026-09-12T14:13:26Z plan created by the executor session on brickertop
  (design line landed in the same slice; 2026-09-08 plan disposed
  superseded). Implementation step left unchecked for the next executor.
