# Research-routes map view (routes/1) — 2026-09-15

Machine session record (jcode deep task graph node `d6-routes-view`,
swarm lane `session_dolphin_1789472126868_b6fe1d64bcfa1dc6`). Landed
commit `0bb09044` + sibling source-file commit `b9f58dc8`. Free-commit
automation lane; no kernel `src/`, `tests/`, `Makefile`, or `hngh.asd`
touched.

## Problem

The research lines ledger had no visual surfacing: 100+ research lines
moved through planned -> expanding -> contracting -> crystallized ->
reviewed with verdicts recorded in
`automation/research-dispositions.tsv`, but nothing rendered the
movement. An operator reading `docs/project/reports.md` or the
dispositions TSV could not see at a glance which routes were adopted,
killed, parked, or still open, nor which ones had been condensed into
lessons by the d1-harvest organ.

## Change

- `automation/jobs/research-routes.py` (new): builds the routes/1
  payload from the research ledgers — lines rendered as routes across a
  time axis. Transitions from the dispositions ledger become segments;
  terminus shape is driven by the line's terminal action (adopted,
  killed, parked, open); a route whose line has an active row in
  `research-lessons.tsv` is marked as harvested. `build()` at
  research-routes.py:241, `main()` at :323; newest-wins cap 100 routes
  per payload.
- `automation/jobs/viz_schema.py`: routes/1 family added —
  `ROUTES_SCHEMA = "routes/1"` (viz_schema.py:60), included in
  `SUPPORTED` (:61), envelope keys `("schema", "generated", "routes")`
  (:84), validator `_validate_routes` registered (:418) with the pinned
  adapter `validate_routes` (:546). Vocabulary pinned from the live
  writers (viz_schema.py:308); envelope extras fail closed.
- `automation/dashboard-server.py`: `GET /research-routes.json` serve
  (dashboard-server.py:378-388, route dispatch :462) — cached (~30 s,
  dashboard-server.py:257-259 module load of the builder), fail-soft:
  a builder hiccup serves the last good payload instead of erroring
  the tab.
- `automation/dashboard/routes-view.js` + `automation/dashboard/
  routes.html` (new; landed separately in b9f58dc8 with `git add -f`
  per the 6fbe8000 precedent after the `dashboard/` gitignore dir rule
  skipped them): SVG polylines over a time axis, lanes by status
  (reviewed / crystallized / planned); termini adopted = filled,
  killed = x, parked = hollow, open = origin dot; violet dot = harvested
  lesson. Routes tab + nav entries added to index.html, gantt.html,
  story.html, app.js (per 0bb09044 stat).
- Vocabulary: status families come from the research-lines.tsv column
  values (viz_schema.py:308); a live-vocab fact learned mid-flight (the
  beat writes `contracting`, which the brief's enumerated states
  missed) is baked into builder, schema, and view alike.

## Verification

- `automation/tests/test-routes-view.py` (new, hermetic, 37 cases,
  704 lines): red-first, green after implementation. Covers builder
  shape, cap, legacy-width disposition tolerance, harvested marking,
  schema fail-closed behavior for the routes/1 family, and the serve
  seam.
- `python3 -B tests/test-routes-view.py` → `Ran 37 tests ... OK` (rc 0)
  on this tree post-commit.
- `python3 -B tests/test-viz-schema-version.py` → `Ran 15 tests ... OK`
  (rc 0): the version probe is green at HEAD because 0bb09044 landed —
  while the slice was uncommitted the probe was red by design
  (byte-equal HEAD certification detects the new routes/1 seam as
  drift; see the 22:36Z d6-routes-view blocker row in
  `automation/agent-handoffs.md`).
- Full gate `cd automation && make test` run at record time; see the
  CHANGELOG 2026-09-15 rows for the landing-time gate statement (43
  suites OK, sole by-design red on the then-uncommitted seam).

## Open follow-ups

- The new surface (jobs/research-routes.py, /research-routes.json,
  routes-view.js) has no patrol route or registry admission yet:
  `config/patrol-routes.tsv` / registry walk does not cover it. Owned
  by the `admit-lessons-routes-surfaces` graph node.
- The dashboard service needs a reload to serve the live route on the
  running instance; tests exercise the serve seam in-process, the
  long-running service picks the new handler up only on restart.
- The feed rebuild clobbers email-driven dismissals (shared with the
  reply-parse surface; see 2026-09-15-email-reply-parse.md) — owned by
  the `fix-email-dismiss-clobber` graph node.
