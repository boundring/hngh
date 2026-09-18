<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z routed-from=dash-selfreview:prune-archive-reconcile-loss -->
# 2026-09-14 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:prune-archive-reconcile-loss`
at 2026-09-14T13:00:39Z. Alert text: [dash-selfreview] ledger-sanity reconcile overreach (2026-09-14): the orphan-body prune deleted 17 untracked daily prune-archive-2026-08-27..09-14.md record files beyond the unreferenced body set; daily archives 09-10..09-14 rebuilt (declared reconstructed) from STATE.md alert-breadcrumb texts (xN refire markers and non-breadcrumb alerts unrecoverable), earlier days zero-recovery — archive files must be excluded from any orphan reconcile

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-14T14:00:39Z re-occurred (dedup window expired)
