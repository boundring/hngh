# 2026-09-02 — biographic cadence design

Status: DESIGN
Date: 2026-09-02

## Scope

Design the standing cadence for the biographic/documentary pipeline. The
2026-09-01 capture row (docs/records/2026-09-01-biographic-capture.md)
established WHAT a capture row is; this design establishes WHEN it lands,
WHO writes what, and HOW the day-tier tick produces it without a human
present.

## Operator directive

The bootstrap directive (hngh `docs/project/plans/2026-09-01-operator-
items.plan.md` step 7, "GROW — first daily biographic capture row")
records the cadence decision verbatim:

> a daily biographic capture row lands in docs/records/;
> docs/journal/ stays machine-owned and is cited, not rewritten

The pipeline's purpose (same plan, directive 6): "a long-term
biographic/documentary pipeline where Hngh maintains notes and records
for operator writing about Hngh's development." The capture rows are
source material the operator draws on when writing; the operator's own
authored suite (`~/Projects/etc/20260830`, docs 00–09) is the exemplar
structure and a cited source — the machine never rewrites it.

## Named cadence tier: `day`

The capture runs on the **day** tier — the daily systemd timer
(`*-*-* 06:00:00` per `cadence/README.md` "Tier schedules"). One capture
row per calendar day, landing as `docs/records/<date>-biographic-
capture.md`.

The day tier already carries eleven drop-ins (`cadence/day/01-…` through
`10-bench-fresh.sh`); the capture mounts as the next lexical slot:

- `cadence/day/11-biographic-capture.sh`

Rationale for `day` over other tiers:
- **Not `hour`/`30m`/`10m`** — a biographic row is a day-sized unit of
  narrative; sub-day tiers produce fragments, and the capture already
  cites those tiers' artifacts (telemetry, breadcrumbs, reports) as
  sources. One row per day is what the directive names.
- **Not `week`/`month`** — those tiers aggregate (`cadence/week/01-
  roadmap-review.sh`, `cadence/month/01-zoom-out.sh`); the capture is
  the raw daily ledger they aggregate FROM, not an aggregation itself.

## Who writes what

| Writer | Artifact | Boundary |
|---|---|---|
| Machine (day-tier drop-in) | `docs/records/<date>-biographic-capture.md` | A records-format row: Status: RECORD, every claim cites a source, admits no runtime capability |
| Machine (day-tier drop-in) | `docs/journal/` (current day) | Machine-owned; the capture cites it, NEVER rewrites it |
| Operator | The exemplar suite and any operator writing | Cited verbatim with a path; never paraphrased into the journal or capture |

The machine composes the daily capture row (narrative + per-claim
source citations, following the 2026-09-01 row's structure). The
operator writing it serves is cited, not generated: if operator-authored
text is quoted, the quote carries its source path.

## Tick behavior (design for the future GROW drop-in)

1. Read the day's machine-owned sources: `docs/journal/` current-day
   file (if present), `docs/project/reports.md` alert rows,
   `docs/project/plans/` plan files touched, telemetry and sweep
   evidence.
2. Compose `docs/records/<date>-biographic-capture.md`: narrative
   sections with `**Sources:**` blocks per claim, per the records spec
   (hngh `docs/records/README.md`: "Records preserve verified facts,
   decisions, and bounded unknowns").
3. Fail-closed in every expected path (day-tier convention, per
   `cadence/day/08-doc-suite-check.sh`): exit 0; a missing source is
   cited AS ABSENT ("no journal entry today") rather than fabricated;
   a genuine fault files an alert row in `docs/project/reports.md`.
4. The capture never modifies `docs/journal/` — reading it is the only
   interaction. Creating the journal's current-day entry remains the
   machine's own journal step, not the capture's.

## Boundaries

- **Machine-owned**: the capture row and `docs/journal/` land without
  ceremony — both are machine-owned dirty paths per the autonomy rule
  (docs/project/plans/2026-09-02-operator-items-follow-on.plan.md).
- **Ceremony-gated**: not applicable — the capture writes only
  machine-owned paths.
- **Forbidden**: no kernel changes; no rewriting of operator-authored
  files or prior capture rows (rows are append-only by date filename).

## Grow↔research alternation fit

The capture is a research-class artifact (records preserve verified
facts; it never writes code). Mounting it on the day tier keeps it out
of the paced ≤60m beat alternation entirely: it runs at the fixed daily
timer alongside the other day-tier drop-ins, consuming what the grow
beats produced the previous day.

## Next steps

- GROW beat: author `cadence/day/11-biographic-capture.sh` per the tick
  behavior above; verify a manual tick produces a dated capture row
  citing today's real sources; `make test` green.

## Sources

- docs/records/2026-09-01-biographic-capture.md (first capture row; the
  cadence decision recorded verbatim)
- hngh docs/project/plans/2026-09-01-operator-items.plan.md (operator
  bootstrap directive: daily capture, machine-owned journal cited not
  rewritten, pipeline for operator writing; step 7 verification
  contract)
- ~/Projects/etc/20260830/ (operator's exemplar suite — the writing the
  pipeline serves; structure exemplar per plan parked section)
- hngh docs/records/README.md (records format spec: "Records preserve
  verified facts, decisions, and bounded unknowns")
- cadence/README.md (tier schedules: day = `*-*-* 06:00:00`; drop-in
  mounting convention)
- cadence/day/ (eleven existing drop-ins — next lexical slot is 11)
- cadence/day/08-doc-suite-check.sh (fail-closed day-tier drop-in
  convention)
- docs/project/plans/2026-09-02-operator-items-follow-on.plan.md
  (autonomy rule: machine-owned dirty paths land without ceremony;
  step 6 acceptance: named cadence tier + source citations)
