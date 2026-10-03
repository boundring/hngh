<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z routed-from=dash-selfreview:ledger-sanity -->
# 2026-09-14 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:ledger-sanity`
at 2026-09-14T00:00:40Z. Alert text: [dash-selfreview] ledger-sanity: unacceptable-now — drift 2407 rows (395 ledger vs 2802 bodies) > 50 — queue panel would show rows whose bodies are gone; reconcile/prune

## Steps

- [x] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Resolution (2026-10-03)

The original finding had two halves:

1. Diagnosis — the 2407-row alert compared report-queue --json's unread-only
   `reports` subset against total body files. Already fixed in c3fda354
   (summary-based count + tree-freshness guard) with a green skew test suite.

2. Residue — two live drift sources remained:

   (a) prune-archive-*.md files were counted as bodies by the check's glob
       (body_path never writes that name). Fixed this session: 120-file failing
       test first, then the archive exclusion in the body glob
       (automation/jobs/dashboard-self-review.py).

   (b) 451 orphaned body files whose ledger rows were pruned (progress 7d /
       alert 14d retention; cross-machine ledger sync deletes bodies on the
       pruner side only). Reconciled: removed 2026-10-03. No ceremony needed —
       docs/project/report-bodies is entirely gitignored (.gitignore:14), unlike
       the older 5fb2ced2 tracked-deletion lane.

Named verification: live check_ledger() returns [] (drift 0) and the automation
script suite (`make test`) is green.
