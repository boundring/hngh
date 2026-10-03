# 2026-10-03 — dashboard deficiency tranche: eight review findings closed

## Conclusion

An adversarial operator review of the automation dashboard
(2026-10-03) surfaced four experience failures: Handle clicks left
articles unchanged; operator-queue items were dense raw check ids;
the activity feed was unrecognizable; and harness features were
invisible, with article interaction feeling state-free. Root-causing
turned those four into eight concrete defects, all fixed in one
day as eight committed, gate-green slices (automation surface,
free-commit lane):

1. `af2c08dc` — verdict override unified in verdictOf: Camp could
   render "ALL CLEAR" directly under a "NEEDS ATTENTION" header
   because the open-items warn override lived only in renderHeader.
   One computation, both surfaces.
2. `c81a391b` — Handle/Acknowledge mark the card in place (dim +
   chip via a `broadsheet-handled` localStorage store). The click
   DID settle server-side; the rebuilt stream just re-rendered the
   same card from the same stale composer snapshot, so the click
   read as a no-op. verbStore() maps each endpoint to its ledger
   side (approved verbs mark, dismissed verbs drop).
3. `d42c247a` — dateline carries edition age ("edition 12m old" /
   "stale edition · 1h 36m old", stale at >=90m) and the open-item
   count; the silent 30s poll now rebuilds when the composer prints
   a NEW edition stamp (the frozen front page), while unchanged
   snapshots still never rebuild (the flash bug stays fixed).
4. `f4b3a68f` — decision buttons carry outcome titles/aria-labels
   from the feed's guidance payload; the guidance card reveals its
   one-line "why" at rest and verb table/details only on expand.
5. `2bb59586` — operator rows decompose producer-first
   (`19-ux-review.sh | alert | ux-review:...` renders producer,
   kind, then the check text; full text in the row tooltip), and the
   broadsheet deck no longer repeats the headline verbatim.
6. `ae51b255` — console History pane renders: history-view.js set
   `#hist-body`, which existed only in the standalone history page,
   so tab mounts showed "204 entries" with zero visible rows. The
   view now builds its own pane skeleton when the mount has none.
7. `ecc964e8` — the hngh-token meta read takes the FIRST NON-EMPTY
   content (two meta tags shipped: real + empty placeholder; a
   document-order read made the placeholder win in some serve
   orders, killing every mutation), and the orphaned
   newspaper-view.js (no page loaded it) is deleted with its suite.
8. `ecc964e8`→this commit — dash-selfreview staleness alerts
   (e.g. "feed-fresh:operator-items.json: unacceptable-now") now
   feed verdictOf as warn reasons; the console glossary names the
   kernel-gate boundary (kernel state is deliberately not surfaced
   here; the last ceremony commit lives on the Plans tab).

## Evidence

- New suites/classes, all red before their fix, green after:
  VerdictOverride (3), HandledInPlace (5, includes a node-exec
  identity test of verbStore's ledger-side mapping), EditionAwarePoll
  (4, node-exec editionAge math), VerbTitles (3),
  GuidanceProgressiveReveal (2), ConsoleHistoryRows (1),
  OpRowDecompose (4), TokenFailSafe (1), SelfReviewSurfacing (3,
  includes the check-name regex pin — `[\w.-]+(?::[\w.-]+)*` so the
  trailing colon of "…json:" is not eaten).
- Full `automation && make test` gate green after each slice
  (~295s each); lint-identifiers and lint-home-paths clean.
- Live browser evidence drove the review: POST
  /operator-item/handle returned 201 while the article stayed
  identical (no state field in newspaper.json, rebuild from the
  cached snapshot); the History tab reported 204 entries with all
  rows at offsetHeight 0; Camp showed the verdict contradiction on
  one screen; dateline carried no age; buttons had title:null.

## Scope

Dashboard client/server and its tests only
(automation/dashboard/*, automation/tests/*, one jobs/ comment).
Kernel src/, Makefile, hngh.asd untouched; no certificate lane
involved (read-only observability plus token-gated operator-item
verbs, per the standing dashboard boundary). Composer-side dedup
(newspaper.json deck) stays a composition concern for a later
slice; the view now dedupes display-side.
