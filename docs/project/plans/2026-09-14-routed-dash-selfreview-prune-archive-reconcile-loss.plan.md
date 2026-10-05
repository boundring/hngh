<!-- plan: status=executed risk=normal accepted=2026-09-18T01:41:57Z routed-from=dash-selfreview:prune-archive-reconcile-loss -->
# 2026-09-14 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:prune-archive-reconcile-loss`
at 2026-09-14T13:00:39Z. Alert text: [dash-selfreview] ledger-sanity reconcile overreach (2026-09-14): the orphan-body prune deleted 17 untracked daily prune-archive-2026-08-27..09-14.md record files beyond the unreferenced body set; daily archives 09-10..09-14 rebuilt (declared reconstructed) from STATE.md alert-breadcrumb texts (xN refire markers and non-breadcrumb alerts unrecoverable), earlier days zero-recovery — archive files must be excluded from any orphan reconcile

## Steps

- [x] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-14T14:00:39Z re-occurred (dedup window expired)

## Resolution (2026-10-05)

The owed fix is landed and verified; this session closes the loop.

1. Check-side exclusion (the finding's ask, "archive files must be
   excluded from any orphan reconcile"): a4b49be7 (2026-10-02) already
   put prune-archive-*.md off the ledger-sanity body glob in
   automation/jobs/dashboard-self-review.py, failing-first via
   automation/tests/test-dashboard-selfreview-ledger-skew.py
   (test_prune_archive_files_not_counted_as_bodies). The standing
   report-queue --prune path only unlinks body files shaped
   <ts>-<kind>-<id>.md and never writes or matches prune-archive-*.md,
   so no standing code path can delete archives.
2. The 17 rebuilt daily archives (2026-08-27..09-14, rebuilt 2026-09-14)
   survived the 2026-10-03 reconcile: 33 prune-archive files present and
   continuous through prune-archive-2026-10-04.md.
3. Alert quiet: zero report rows remain for identity
   dash-selfreview:prune-archive-reconcile-loss (aged out, no refire
   since the exclusion).

Named verification (2026-10-05): live check_ledger() returns [] (drift 0)
and the automation gate (`make test`) is green.
