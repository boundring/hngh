<!-- plan: status=accepted risk=normal accepted=2026-09-09T20:45:18Z -->
# 2026-09-09 — work-graph feed + gantt plan reality (visualization rung 1)

Authorization: operator-directed 2026-09-09 (dashboard gantt as the
visual guide to staged/completed work). North star:
docs/design/work-visualization-direction.md. This plan ships the
foundation rung: the work graph in the feed layer and plan-reality on
the gantt. Story/comic/animation rungs read this same graph later.

## Steps

- [ ] 1. Extend automation/jobs/plan-feed.py to emit the work graph:
      for each plan in docs/project/plans/, parse the step list
      (checked/unchecked + Verification names), the front-matter
      (status/risk/accepted/priority/cause), and execution-notes
      dependency lines; emit steps arrays and an edges list
      (unlocks/feeds/parked-because) into dashboard/plans.json
      alongside the existing summary fields. Keep the existing
      summary fields byte-compatible (the gantt and sessions views
      already consume them). Parse failures for one plan must not
      break the feed (fail-closed per plan, alert row on parse error).
      Verification: suite test covers step parsing, edge extraction,
      and per-plan failure isolation; regenerated plans.json carries
      steps+edges for at least the three 2026-09-09 priority plans;
      `make test` green.
- [ ] 2. Gantt upgrade: accepted/executing plans render as step rows —
      one lane per plan, sub-bars per step (filled = done, pulse =
      next unchecked), blocked-by edges drawn from the edges list,
      park-cause chips from the cause field. The estimate-honesty
      header stays (estimates are projections; step checkmarks are
      facts).
      Verification: gantt.html opened against the live feed
      shows the priority plans' step structure; a parked plan renders
      its cause chip; no console errors; screenshot captured to the
      dashboard evidence path.
- [ ] 3. Story view skeleton (rung 2 of the direction): a new
      dashboard page rendering today's chapters from the work graph +
      report-queue ledger: accepted, steps-completed (commit-hash
      footnotes), blockers, parks. Static fetch-and-render like the
      other tabs; one dry aside per section maximum (voice rules in
      docs/design/presentation-direction.md).
      Verification: page renders from live plans.json + reports feed;
      link checker passes; a11y spot-check (aria labels on sections,
      keyboard focus) folded in from the parked ux-review findings;
      `make test` green.
- [ ] 4. Records: CHANGELOG entry + docs/records/ entry for the
      work-graph feed (cross-linking
      docs/design/work-visualization-direction.md).
      Verification: `make test` green; record cross-linked from
      CHANGELOG.

## Execution notes

- Step 1 is the foundation; 2 and 3 both consume it and are otherwise
  independent; 4 last.
- Comic/animation renderers are explicitly out of scope here — they
  are later rungs consuming the same graph (the direction doc records
  the mapping: chapters→panels, sessions→characters, the TUI sprite as
  protagonist).
- Honesty rules are binding: no invented dates, estimates labeled,
  blocked-by drawn only from real evidence.
