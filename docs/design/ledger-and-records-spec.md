# Ledger and records

Status: DESIGN — telemetry/records split, research and session-cost capture,
from the operator's third-evening intake (session-notes §9), 2026-08-27.

Source: `../../docs/project/session-notes-2026-08-27.md` §9; current surfaces:
`report-queue`, `time-ledger.sh`, cadence breadcrumbs, oversight crumbs,
supervision state.

Cross-links: [display-register-spec.md](display-register-spec.md),
[system-awareness-map.md](system-awareness-map.md),
[interface-grading.md](interface-grading.md),
[../../docs/project/roadmap.md](../project/roadmap.md).

## 1. Problem

One append-only markdown ledger (docs/project/reports.md) carries both
high-frequency telemetry (timer results, oversight findings, supervision
flags — rows every five minutes) and curated records (ceremonies,
witnesses, decisions). The costs are now measured: unbounded growth (the
2026-08-27 flap wrote 8,876 alert rows in ~30h), prune is a full-file
rewrite, nothing is queryable, and the data dashboards most need —
per-session cost, model, duration; per-research-subject spend and
references — is never captured at all. The Schedule tab's estimates were
built on whatever journalctl happens to print.

## 2. Decision (proposal): two stores

- **Curated record stays git-tracked** (project ledger, records, session
  notes): low-frequency rows only — ceremonies, witnesses, decisions.
  This is the public record and the changelog's backbone.
- **Telemetry store**: one local SQLite file in WAL mode
  (`dashboard/telemetry.db`) written through python's stdlib `sqlite3` —
  no daemon, no dependency, still a single file. journald structured
  fields remain the optional adapter for per-unit operational lines
  (journald already rotates and vacuums). JSONL is an export format, not
  the store.

Schema v0: `events(ts, source, kind, identity, lane, unit, model,
tokens_in, tokens_out, cost_usd, wall_s, subject, refs, body)`. Redaction
at write time, inheriting the credential pattern from
`scripts/verify-candidate.py`. Retention tiers: raw 7d, rollups 90d,
curated permanent (git). The markdown prune command keeps its contract
until the store is the sole reader, then retires.

## 3. Producers (capture first, views second)

- `report-queue` dual-writes: the git row is unchanged; the store gets an
  insert with the same identity (dedup/flap counting becomes SQL).
- cadence-tick walls (already in drop-in-timing.log) land as `wall_s` rows.
- supervision stalls/recoveries land with their identity.
- ceremony receipts land per step (create-run, prepare-candidate, commit,
  push — ms timings already exist).
- **session-cost capture** (new): token usage parsed from omp transcripts
  plus the hngh loadout cost/time limits, one row per session — feeds the
  Sessions columns the operator asked for (model, duration, cost, purpose)
  without renaming anything.
- **research-beat capture** (new): one row per research beat — subject,
  category, model, tokens, cost, references, search calls and engines —
  so the Research view can show spend per subject from real data.

## 4. Consumers

LogsView (tail, facet by source/kind, event-rate histogram — uPlot per
stage 6); Research tech-tree (per-subject time/spend/references, edges =
prerequisite lanes); Sessions meta columns; gantt actuals (already);
self-optimization rollups. Strategy-game-style research UI is the
target presentation, gated on §3's capture existing first.

## 5. Sequencing and failure

Producers land before any view work. Every producer fails closed: store
unavailable → current file behavior continues. No daemons; the store is
rebuildable from the journals and transcripts that feed it.

## 6. Referenced standards

Twelve-factor logs (event streams, the app does not manage routing);
structured events (logfmt/JSON lines) as export shapes; OpenTelemetry
vocabulary (spans around ceremonies/ticks) for naming only — no SDK.
