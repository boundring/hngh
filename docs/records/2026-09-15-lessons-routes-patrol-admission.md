# Research lessons + routes surfaces admitted to patrol and registry

Date: 2026-09-15
Commit: b95f1d3d
Lane: automation free-commit (machine session, node admit-lessons-routes-surfaces)

## The gap

The plan::gate audit of d1-harvest (research harvest organ) and
d6-routes-view (routes/1 map) against the five-part admission rule
(registry declares / guard fails closed / patrol watches / certificate
mutates / disposition records) found both new organs unwatched and
undeclared:

- `config/patrol-routes.tsv` had no row covering
  `research-lessons.tsv` or `research-routes.json`.
- `jobs/patrol.py` FEEDS freshness covered only plans.json,
  operator-items.json, sessions.json.
- `torch-ledger.tsv` had no rows for research-lessons.tsv,
  research-routes.py, research-routes.json.

Consequence: a dead harvest or a cold /research-routes.json serve was
invisible to the formal rounds.

## What landed

- Patrol manifest: `research-ledger` row, 30m tier, bad-execution
  finding class, surface lessons-ledger.
- Patrol check: `check_research_ledger` in `jobs/patrol.py` -- the
  deterministic lessons-ledger walk:
  - `ledger-missing`: research-lessons.tsv absent.
  - `header-drift`: first line != the 6-column LESS_SCHEMA.
  - `row-malformed`: a data row whose width is not 6 or with an empty
    lesson_id (per-row FAIL, the walk continues).
  - `lineage-contradiction`: an active lesson whose newest disposition
    action is parked/killed (the harvest contract says the knowledge
    record never outlives its verdict; newest-wins scan, unknown-action
    rows skipped, same reading rules as the harvest/routes builders).
  - `harvest-stale`: an adopted disposition inside the 6h
    `LESSONS_STALE_HOURS` budget with no lesson row dated inside the
    budget (the beat harvest runs at disposition landing; a miss means
    the organ is dead).
- Feed freshness: `research-routes.json` in FEEDS at 28800s (8h). The
  feed is built on demand by the dashboard serve path with a 30s cache,
  so the mtime budget is the feed tier (between plans.json's 1h and the
  stale-only-if-dead regime), not a cadence tier; the 30m patrol sees a
  dead builder within its first walk after 8h.
- Torch ledger: `research-lessons.tsv` row (pattern
  `research-lessons\.tsv`, writer research-harvest.py) and
  `research-routes` row (pattern `research-routes`, writer
  research-routes.py). Both re-verified through the audit's own
  consumers() seam: 8 and 4 non-writer consumers, expected live.

## Tests (red-first)

`tests/test-patrol.py`: 8 new cases (healthy-quiet, feed stale,
feed missing, ledger missing, header drift, malformed row, lineage
contradiction, harvest stale); the healthy base fixture now seeds both
surfaces; the count-sensitive expectations moved 19->21 PASSes and
15->16 results. Verified red before the production change, green after.

## Validation

`cd automation && make test` green twice (before the ledger note edit
and after), identifier lint clean, live-ledger probe of the new check
(69 active lessons, no findings), manifest/CHECKS resolution sweep (25
routes, 0 unresolved).

## Deliberate boundaries

- No warning-state semantics: an active lesson whose newest disposition
  is unknown (line not in the dispositions ledger) is not a finding.
- No `research-lessons.tsv` mtime freshness: content correctness beats
  file mtime; the ledger is only rewritten when harvest changes rows.
- The live dashboard process still needs a service reload to serve
  /research-routes.json from a restart (pre-existing deployment step,
  outside this slice); the patrol now fires within 8h if the builder
  stays dark, which is the gap this slice closes.
