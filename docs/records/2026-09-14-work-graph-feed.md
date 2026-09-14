# 2026-09-14 — work-graph feed: the plan ledger as one graph, many renderers

Plan: docs/project/plans/2026-09-09-work-graph-visualization.plan.md
(operator-directed, accepted 2026-09-09). Direction doc:
docs/design/work-visualization-direction.md — build the work graph once
in the feed layer, let renderers compete. This record is the close-out
of the plan (all four steps): what landed, where it lives, and what
stays open for the later rungs.

## The gap it closes

Before this feed, the gantt rendered the timer schedule and the plan
queue lived separately in plans.json as text — two truths for the
operator asking what is staged, what is done, and what is next. The
direction doc's fix: one graph (plans as nodes, steps inside active
plans, edges for unlocks / feeds / parked-because) built in the feed
layer, consumed by every present and future surface.

## What landed

- **Work graph in the feed layer** (plan step 1,
  `automation/jobs/plan-feed.py`): per plan it now parses the step
  list (checked/unchecked plus Verification names), front-matter
  (status/risk/accepted/priority/cause), and execution-notes dependency
  lines, emitting steps arrays and an edges list
  (unlocks/feeds/parked-because) into `dashboard/plans.json` beside the
  existing summary fields. Summary fields stay byte-compatible; a
  parse failure in one plan breaks that plan only (fail-closed per
  plan, alert row on the error). Suite test
  `automation/tests/test-plan-feed-graph.py` covers step parsing, edge
  extraction, and per-plan failure isolation.
- **Gantt plan reality** (plan step 2, machine-data `dashboard/`,
  not committed): accepted/executing plans render as step rows — one
  lane per plan, sub-bars per step (filled = done, pulse = next
  unchecked), blocked-by markers drawn from real edges, park-cause
  chips from the cause field. The estimate-honesty header stays:
  estimates are projections, step checkmarks are facts. Live-verified
  via puppeteer against 127.0.0.1:8890/gantt.html (34 plan lanes, 3
  cause chips, zero console errors); screenshot at
  docs/media/gantt/plan-rows-20260914.png.
- **Story view skeleton** (plan step 3, machine-data `dashboard/` +
  `automation/tests/test-story-view.py`, wired into make test):
  `story.html`/`story-view.js` render today's chapters from the work
  graph + report-queue ledger — accepted, steps-completed (commit-hash
  footnotes drawn only from the feed's `last_ceremony_commit` and hex
  tokens in today's report rows), blockers (real edges + today's alert
  rows), parks (front-matter cause chips). Static fetch-and-render;
  aria-labelledby + tabindex on every section (folded in from the
  parked ux-review findings); one dry aside per section maximum per
  docs/design/presentation-direction.md. Live-verified via puppeteer
  against 127.0.0.1:8890/story.html (four sections, 40 cause chips, 90
  plan links, a11y flags pass, zero console errors); screenshot at
  docs/media/gantt/story-20260914.png.
- **Records** (plan step 4): this record and the CHANGELOG entry,
  cross-linked to the direction doc.

## Honesty rules held

No invented dates; estimates remain labeled projections; blocked-by is
drawn only from real unlocks/feeds edges and today's alert rows, never
from guesswork. The gantt's dashed estimate bars say "estimate"; step
cells say "fact".

## Later rungs (out of scope here)

Comic strip and animation renderers stay future rungs on the same
graph (chapters become panels, sessions become characters, the TUI
operative sprite becomes the story's protagonist); the mapping is
recorded in the direction doc. Nothing in this plan blocks them.
