---
category: observation/telemetry/eventing
persona: The Observer
status: seed
anchored: 2026-10-03
note: automation anchors predate the 2026-10-04 control-room cut (broadsheet/ghost/wire surfaces retired)
---

# Observation, Telemetry & Eventing — what hngh runs today

hngh's observation spine is three append-only ledgers plus JSON feeds served over a fail-closed HTTP surface. **Crumbs** (activity journal): single-writer `automation/lib/crumbs.py` with `lib/breadcrumbs.sh` as stable-API shim (automation/CHANGELOG.md:436); `lib/crumbs-db.py` imports complete `ts | job | event | detail` lines past a byte-offset watermark into `state/crumbs.db` (SQLite WAL, additive-only DDL, fail-open exit 0) as a derived index only (kernel CHANGELOG.md:577-583). `cadence/subhour/15-crumbs-sync.sh` re-exports the STATE.md mirror and verifies parity, filing ONE evidence-gated alert (`crumbs-mirror:<kind>`, `--window 0`; the same evidence token never re-alerts) on mismatch (automation/cadence/subhour/15-crumbs-sync.sh:1-28). Rotation keeps 14d of ordinary rows, alert/finding/decision forever (automation/cadence/calendar/daily/02-ledger-prune.sh:2-6).

**Report queue** (findings ledger): append-only rows in `docs/project/reports.md` with body sidecars, five kinds (progress|expense|optimization|scheduled|alert), identity dedup with ` ×N` folding and an `--evidence` token so a stale condition re-fires only on real recurrence (scripts/report-queue:2-49,388-399).

**Feeds**: subhour producers write operator-items.json, readout.json (queue/timeline/verdict spine), sessions.json, plans.json, system/sessions feeds (automation/cadence/subhour/ listing:05-readout.sh:14-24); fleet.json is refreshed by the newspaper composer, fail-soft to last good (automation/cadence/subhour/25-newspaper-compose.sh:18-26). **SSE push**: `GET /events` in `automation/dashboard-server.py:800-803,1092-1124` watches mtimes of the attention feeds (readout + operator-items/dismissed; EVENT_WATCH at :309-313) at `SSE_POLL_S=0.5`, emits one no-payload `change` event per change (client re-fetches the small feed), heartbeat comments every 15s, clean close on disconnect. Every GET is source-allowlisted (tailnet CGNAT default, everything else DENIED; automation/dashboard-server.py:736-740).

Self-observation closes the loop: `jobs/dashboard-self-review.py:2-27` runs procedural checks — freshness (stale beyond 3× tier), validity (parses + required keys), served (page 200 + expected marker), ledger (row/body drift with a tree-skew guard) — classified `unacceptable-now` vs `acceptable-for-now`, filed as deduped `dash-selfreview:<check>` alert rows; all-clear ticks are silent and the tick itself fails closed.

## Open questions for web research

1. SSE vs WebSocket vs long-poll for local control rooms — reconnect semantics and mtime-watch fanout scaling.
2. SQLite-mirror-over-append-only-text (watermark import) as a pattern: consistency, rotation, and backfill precedents.
3. Feed contract versioning when several surfaces (dashboard, broadsheet, newspaper) consume one JSON feed.
4. Alert dedup by (identity, evidence-token): how do pager/incident systems model "same alert" vs "recurred condition"?
5. Lightweight telemetry for LLM/agent spend (per-call token/cost ledgers) — schema precedents.

## Candidate external systems to survey

- OpenTelemetry
- Vector / Fluent Bit
- Grafana Loki
- Sentry (dedup + fingerprinting)
- Netdata (local-first dashboards)
