# 2026-10-04 — harness-skeleton program: control-room cut (phase C1)

## Conclusion

The operator-approved harness-skeleton program's first execution phase
retired the newspaper/wire surface and made the control-room console the
dashboard's single working surface. 22 files deleted outright
(-5636 lines of dead lanes), 46 files changed overall
(+455/-6603, commit 2e6ea458). The broadsheet front page, its WebGL
paper shader, the ghost-counsel lane, the wire/news ingest lane, and the
story/gantt/sessions standalone pages are gone; `/` now serves a minimal
control-room shell (title `hngh control room`, the live megastructure
map slot, a link to the nerve center); retired paths 302-redirect to
`/`; the composer no longer composes wire/ghost/onthisday cards; the
three.js map module and fonts stay (phase C2 promotes the map to the
primary surface).

## Evidence

- Discovery: four scout censuses (dashboard features, repo subsystems,
  Omarchy seams, kernel/ceremony shape) + a frozen two-rubric jevify
  (28 subsystem rows, 28 feature rows) whose verdicts landed in
  docs/agent-notes/jevify-2026-10-03-subsystems.md and
  -dashboard-features.md; verdict overrides recorded in both files.
- Research corpus: docs/research/01..12-*.md seeded from repo evidence
  with file:line anchors (commit e306830d), one lane per persona
  (supervision/init, packaging, configuration, secrets, scheduling,
  observation, decision/ceremony, delegation, ML-for-systems,
  federation, interfaces, failure recovery).
- Deleted lanes: broadsheet.html/.css/.view.js/.sample.json,
  story.html/.view.js, gantt.html (gantt.js engine kept —
  schedule-view.js consumes it), sessions.html/.js,
  lib/ghost-voices.py + config/ghost-voices.tsv,
  scripts/news-ingest.py + config/news-feeds.tsv,
  scripts/this-day-ingest.py, and their tests
  (test-broadsheet-view, test-story-view, test-ghost-voices,
  test-news-*, test-newspaper-window). ConsoleHistoryRows and
  TokenFailSafe contracts were extracted to surviving suites first.
- Survivors kept honest: 35-news-ingest.sh reduced to its weather leg;
  composer docstring + intake rewritten (session/research/operator/
  parked desks only, SESSION_CAP 8); dashboard-introspect.py cut to 6
  surviving intents; self-review PAGE_MARKERS re-anchored to the
  control-room shell; operator-items-feed FLOOD_NEEDLE comment now
  cites the composer; .gitignore un-ignore rows for deleted assets
  removed; cadence-params rows for ghost/introspect-expansion deleted.
- `make smoke` after the cut: index/data checks green after the smoke
  marker followed the page rename (`hngh-automation` → `control-room`).
  The two digest FAILs are a pre-existing two-home skew — smoke checks
  `digest/$TODAY.md` relative to automation/ while DIGEST_DIR resolves
  to ~/.hngh/archive/digest (only REVIEW-*/SYNTH-*/BENCH-* files live
  there; the MORNING- file naming never matched the check). Fixing
  smoke's digest resolution is repo-root scripts/ surface — ceremony
  label required; parked for the operator.

## Scope

No kernel src/ touched (triple-kernel stays at the design stage —
docs/design/triple-kernel.md plus three ceremony plan drafts, bodies
pending). The megastructure-sim and federation designs landed earlier
in the program (006b5720, 4080b31d). Phase C2 (map as primary surface
with live states + attention rail) executes on top of this cut.
