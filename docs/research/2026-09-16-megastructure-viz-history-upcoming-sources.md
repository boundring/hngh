# 2026-09-16 — Megastructure viz: history + upcoming-work data sources (explore)

Explore artifact for the megastructure-visualization design
(docs/records/2026-09-14-jcode-shared-sense.md lineage; viz wave). The
two questions: what data exists for a RECENT-HISTORY view, and what
exists for an UPCOMING-WORK view. Everything verified read-only
2026-09-16.

## Recent-history sources (all landed)

| Source | Contents | Freshness | Access |
|---|---|---|---|
| git log spine | every commit = a fact; slice messages by prefix (automation:/docs:/research:/hngh:) | live | `git log --since` |
| automation/CHANGELOG.md + repo CHANGELOG.md | human-curated highlights per slice | per-commit | file |
| docs/journal/*.md | dated working entries | daily | file |
| docs/records/*.md | point-in-time decisions/adoptions (79+ files) | per-event | file |
| automation/logs/budget.md | session-run rows: who spent what, class, model, source | per-session | file |
| automation/agent-handoffs.md | lifecycle rows: spawned/dead/respawn + cause | per-event | file |
| docs/project/reports.md | machine reports (alert/progress verdicts) | 10m cadence | file |
| automation/state/ocgo-agent-lessons.md | failure classes + countermeasures | per-failure | file |
| ~/.jcode/ambient/transcripts/*.json | ambient cycles: actions, memories, summaries (7+ cycles) | ~4h | file |
| dashboard/sessions.json | live session roster (271 session files parsed) | 1m feed | HTTP/file |
| torch-ledger / viz-schema routes/1 | disposition transitions as route segments (landed 09-15, `routes/1` family with fail-closed envelope) | 8h feed tier | /research-routes.json |

Verdict: a history view needs **zero new plumbing** — every source is a
landed file or feed. The work is selection + layout only.

## Upcoming-work sources (all landed)

| Source | Contents | Access |
|---|---|---|
| scripts/report-queue --json | queue roster with priority (drives Schedule tab) | CLI/JSON |
| docs/project/plans/*.plan.md | checkbox state = upcoming steps per plan | file |
| automation/dashboard/plans.json | plans feed already served | HTTP |
| automation/dashboard/schedule.json | schedule feed | HTTP |
| docs/project/roadmap.md stage table | stages with exit criteria + state | file |
| automation/state/pending-checks.tsv | converged pending checks (09-15 organ) | file |
| automation/state/rotation-watch.tsv | rotation-due tracking | file |
| ambient state.json `.status.Scheduled.next_wake` | next ambient cycle | file |
| jcode ambient `schedule_*` queue entries | ambient self-scheduled work | file |

Verdict: upcoming-work view also needs **zero new plumbing**. The gantt
view already renders timeline shapes; plans/schedule feeds exist.

## Constraints

- Display register + factual-renderer law: visualization is display
  layer, never governance input (graph-view.js header states the same).
- Writing register for any narrative labels.
- ~270 session files: size-bounded reads; the graph feed's 30s cache
  pattern (jobs/dashboard_feed `_tele_cache`/`_graph_cache`) is the
  template.

## Recommended first increment

A "Recent" panel section composed entirely from existing feeds:
budget.md tail (spend), agent-handoffs tail (lifecycle), ambient
state.json last_summary, and git log --since -24h grouped by prefix.
S effort; no new endpoints if served as static compose into an existing
feed build step (the `dashboard_feed` caching pattern).

Confidence: high on sources (all read live today). Not verified: exact
row counts at scale for budget.md/handoffs (bounded tails recommended),
and whether reports.md rows are stable schema (rp-ledger hazards record
2026-09-15 documents known row-format drift).
