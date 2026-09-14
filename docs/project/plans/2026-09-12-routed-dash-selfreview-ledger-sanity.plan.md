<!-- plan: status=executed risk=normal accepted=2026-09-13T00:36:02Z routed-from=dash-selfreview:ledger-sanity -->
# 2026-09-12 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:ledger-sanity`
at 2026-09-12T23:00:49Z. Alert text: [dash-selfreview] ledger-sanity: unacceptable-now — drift 2442 rows (80 ledger vs 2522 bodies) > 50 — queue panel would show rows whose bodies are gone; reconcile/prune

## Steps

- [x] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
      (2026-09-14 landed: check compared --json's unread-only `reports`
      against the full body glob — 66b67cf counts total ledger rows via
      the summary kinds + unread-subset regression test; 81 unreferenced
      report-bodies reconciled/pruned, landed with the hourly ledger
      sync (5f876e0) after the sibling 48h-prune commit c0c0bd5; final
      check silent, automation make test green. Note: 17 daily
      prune-archive-* files were unrecoverably lost in the reconcile
      sweep; rebuilt from STATE.md breadcrumbs where coverage exists,
      loss recorded in an alert row)
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-13T00:00:13Z re-occurred (dedup window expired)
- 2026-09-13T01:00:49Z re-occurred (dedup window expired)

- 2026-09-14T12:5xZ step landed by the executor session on brickertop:
  root cause was the check comparing --json's unread-only `reports`
  count against the full report-bodies glob (237 unread vs 3004 files
  -> 2767-row pseudo-emergency while the ledger was actually coherent).
  Fix: count total ledger rows via --json `summary` kinds (66b67cf,
  pushed; unread-subset regression test in
  automation/tests/test-dashboard-selfreview-ledger-skew.py).
  Second half: 81 unreferenced report bodies reconciled (64 tracked
  orphans pruned in the 48h-reconcile lane -> hourly ledger sync
  5f876e0; sibling session independently landed 19 via c0c0bd5) and 17
  untracked daily prune-archive-*.md restore-attempted from STATE.md
  alert breadcrumbs (coverage starts 2026-09-10; earlier days zero
  recovery; loss declared in alert row
  dash-selfreview:prune-archive-reconcile-loss and must be excluded
  from future orphan reconciles). Final: check silent, automation
  `make test` green (ALL PASS, lint clean).
