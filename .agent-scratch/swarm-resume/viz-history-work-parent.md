# viz-history-work (parent synthesis): history + upcoming-work views

Date: 2026-09-15. READ-ONLY exploration. Builds on hist-renders-b.md,
viz-graph-payload.md, viz-history-payload.md, hist-windows-schema.md
(work-sources.md absent). Scope: how recent history (commits, incidents,
dispositions) and upcoming work (queue, plans, stages) can render as
examinable visual structures; data sources inventory, view designs,
effort estimates.

## 1. Data sources inventory

### Already-served feeds (zero new backend work to read)

| feed | producer | contents | consumed today by |
|---|---|---|---|
| `/graph.json` | jobs/graph-data.py | current-state nodes/edges, state pre-baked from recency (2h telemetry, 10min sessions, 24h patrol lookback) | graph-view.js (60s HnghPoll) |
| `plans.json` | jobs/plan-feed.py | `generated`, `queue_next`, `last_ceremony_commit{hash,date,subject}`, `alerts[]`, `plans[]` (slug/status/risk/accepted/steps_total/steps_done/priority/cause/steps[]/edges[]) | plans-view.js (table), story-view.js (today narrative) |
| `schedule.json` | jobs/schedule-feed.py | `generated`, `recurring[]` (name/unit/tier/interval_s/next_epoch/last_epoch/source/hngh), `oneoff[]`, `degraded` | schedule-view.js -> gantt.js engine |
| `reports.md` (symlink mirror) | kernel report-queue ledger | pipe-table rows `| YYYY-MM-DD T... | kind | ...`; `report:` sidecar bodies | story-view.js (todayRows date-prefix slice), app.js queue widget (unread via report-cursor) |
| `sessions.json` / `/session/<id>` / `/telemetry.json` | sessions-feed.py, telemetry.py | roster + conversation entries; 24h spend buckets | sessions-view.js, overview-view.js |
| git log | repo itself | commit spine (`git log --format='%s%x09%h' --since/--until` — exactly `scripts/generate-publication day_commits()` lines 103-111; candidate/labeled counting in `day_stats` 129-133) | publication script only; NOT yet a dashboard feed |
| `docs/records/*.md`, `docs/journal/<date>.md` | kernel docs | architecture records (date-slug filenames), daily journal | publication; no dashboard consumer |

### The spine these views should consume: history/1 merged feed (hist-windows-schema.md)

Pinned envelope `{"schema":"history/1","entries":[...]}` (viz_schema.py:72-85,
test exists). Flat entries, prefix-tagged keys (`gitlog:<sha40>`,
`report:<ts>-<kind>-<id>`, `records:<date>-<slug>`, `journal:<date>`),
fields `ts` (Z-normalized), `summary`, plus additive `source/author/short/kind/ref`.
Newest-first, dedup fail-closed. **Not yet produced** — the producer job is
prerequisite backend work (see effort, section 4).

## 2. What already renders (do not duplicate) — from hist-renders-b.md

- graph-view.js: current snapshot, NO time axis; recency baked into states.
- story-view.js: TODAY-only narrative; `todayRows()` is a working reports.md
  date-window slicer (generalize, don't re-implement); `HEX`+`hashesFor`
  footnote extraction; caps + "(N of M shown)"; fail-closed banner ids.
- plans-view.js: plans table (search/status chips/newest-first, tbody-only
  re-render, module `ui{}` state) + queue_next/last-ceremony fact cards.
- schedule-view.js + gantt.js: the ONLY time-axis renderer today — cascading
  gantt (6h/24h/72h zoom, drag pan, now-clamp, recurring cadence projection,
  system backdrop band, deep links). Any history timeline should reuse this
  engine (`window.GanttEngine.mount`) rather than build a second axis.
- sessions-view.js: conversation event streams; app.js queue widget: unread
  ledger queue (respect report-cursor read/unread boundary).
- Conventions to inherit: fetchJson/fetchText abort helpers, esc(), owned
  `<style>` tag, window.HnghPoll for refresh, dim placeholders, headless
  pure-function test seams, "display layer only, never governance input".

## 3. View designs

### View A — History spine view (new tab or section, consumes history/1)

Design: vertical reverse-chron stream of merged entries, source-tagged chips
(gitlog/report/records/journal), each row = ts + source chip + summary +
evidence link (`ref` sidecar/record/journal path via jailed `/hngh-docs/`
route, like plans-view plan links; gitlog rows link the `short` hash).
Filter chips per source + per `kind` (progress/alert/...); optional day
grouping headers (records/journal sort to their day at T00:00Z). Window
selector (24h / 3d / 7d) computed server-side in the producer, not the
client (hist-renders rule 5). Caps + "(N of M shown)" per source.
Reuse: generalized todayRows pattern is subsumed by the feed; footnotes via
existing hashesFor habit; HnghPoll at 60s or manual refresh like plans-view.

### View B — Upcoming-work view (mostly wiring existing feeds)

Design: "what's next" board, three zones:
1. Queue next: plans.json `queue_next` + `last_ceremony_commit` fact card
   (plans-view already renders these verbatim — link or embed, not duplicate).
2. Next runs: schedule.json recurring sorted by `next_epoch`, chip-style
   "in <eta> · every ~<interval> · ×N" (schedule-view's cadence chips, list
   form instead of gantt); one-off entries with estimate + depends-on.
3. Plan steps: open plans (status accepted/executing) with steps_done/total
   progress bars and next undone step title; parked plans quoted cause.
`alerts[]` surface at top when non-empty (currently always empty in feed).

### View C — optional: day-in-history column chart

Reuse gantt.js engine: past side of the timeline gets day-density marks from
history/1 (commits/day, alert rows/day) — mirrors schedule-view's "small
readout.json for past timeline marks" pattern. Lowest priority; the stream
(view A) already answers the question.

## 4. Effort estimates (jcode-session scale)

| item | effort | notes |
|---|---|---|
| history/1 producer job (gitlog+reports+records+journal merge, validate via viz_schema CLI, atomic publish) | M (1-2 sessions) | spec fully pinned in hist-windows-schema.md incl. gotchas (dedup keys, ts normalization, missing sidecars, prune-archive skip); failing test first per engineering rules |
| serve `/history.json` in dashboard-server | S | trivial feed passthrough + short cache, graph_feed() pattern |
| View A history stream | M | mostly render plumbing; conventions pre-established |
| View B upcoming-work board | S-M | all feeds exist; largest part is deciding link-vs-embed with plans-view/schedule-view |
| View C gantt past-marks | S | optional, engine exists |
| contract tests (headless pure helpers: filter/window/cap logic; feed validation already gated) | S-M each view | same seams as graph-view/story-view |

Total: ~2-3 sessions for A+B with the producer; C is a cheap follow-up.
Everything is display-layer; no governance surface touched; no kernel src/
edits needed (producer lives in automation/jobs free-commit lane, but note
repo-root scripts/ is kernel surface if generate-publication were reused —
prefer a fresh automation/jobs job over extending scripts/generate-publication).

## 5. Open questions / not checked

- Where View A/B mount (new tab vs index.html sections) — ui-evolve
  current-overlay.json is dirty in the tree; coordinate with that work.
- Whether alerts[] in plans.json ever populates (empty today).
- Overlay/grid integration timing vs roadmap stage 6 widget grid.
