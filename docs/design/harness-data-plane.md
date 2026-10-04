# Harness data plane — stores, pipelines, buses, routes, end-forms

Status: design (2026-10-04; the operator-named deliverable "database schemas, data
pipelines, message buses, optimized routes and end-forms"). Sections 1-4 describe
the automation data plane as built, every claim anchored file:line; section 5 names
what is missing. No kernel surface (src/, tests/, Makefile, hngh.asd) is touched.

Premise: the data plane is file-first. Two sqlite event journals, tab-separated
ledgers for machine state, markdown ledgers for operator-visible records, derived
JSON feeds polled by the display layer. There is no message broker; the bus role is
played by append-only ledgers driven by a systemd cadence. Two homes: ~/.hngh is
userspace data (automation/lib/hngh_home.py:2-11), ~/.hngh-automation is secrets
and automation state (automation/config.env:92, :37-38); kernel/gate/certificate
state never moves into either (automation/lib/hngh_home.py:2-11).

## 1. Database schemas

### 1.1 SQLite stores

**crumbs.db** — the event journal. Default path automation/state/crumbs.db (seam
HNGH_CRUMBS_DB, cadence/calendar/daily/02-ledger-prune.sh:37). Schema inline at
automation/lib/crumbs-db.py:38-46:

- `crumbs(ts TEXT NOT NULL, job TEXT NOT NULL, event TEXT NOT NULL, detail TEXT
  NOT NULL, writer TEXT)` with index `idx_crumbs_event(job, event, ts)`.
- `crumbs_meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)` — carries
  `state_byte_offset`, the export fence (crumbs-db.py:173-197).
- No primary key on crumbs; each row's provenance is the writer stamp
  `<writer>@<rowid>` computed at insert (crumbs-db.py:149-168).

Writer: exactly one seam — `crumb(job, event, detail)` at
automation/lib/crumbs.py:50-64, wrapped for shell by `breadcrumb()` at
automation/lib/breadcrumbs.sh:14-25. Fields containing `|` or newlines are
refused at the seam (crumbs.py:54-57) and whitespace-folded by `scrub`
(:44-47). Writes are `BEGIN IMMEDIATE` under `journal_mode=WAL`
(crumbs-db.py:149-168).

Readers: `export --write-state` appends to STATE.md (crumbs-db.py:173-197);
`verify` prints `verdict=ok|mismatch` with an evidence token (:213-252); the
dashboard breadcrumb slice (automation/lib/common.sh:145); the operator keyword
scan (automation/jobs/operator-items-feed.py:2-22).

Retention: `rotate` prunes rows older than 14 days except events in KEEP_EVENTS =
alert/finding/decision, which live forever; pruned rows archive first to
~/.hngh/archive/crumbs-archive.tsv (crumbs-db.py:36, :255-300). Rotation owner:
cadence/calendar/daily/02-ledger-prune.sh:1-15.

Failure mode: fail-open by design — any fault exits 0 silently
(crumbs-db.py:13-15, :330-331). Loss is policed only by `verify` and the
crumbs-mirror alerts (cadence/subhour/15-crumbs-sync.sh:5-24).

**telemetry.db** — spend and run events. Path ~/.hngh/db/telemetry.db via
`hngh_home.db_dir()` (automation/jobs/telemetry.py:21-24,
automation/lib/hngh_home.py:47-49). Schema inline at telemetry.py:25-27:
`events(ts, source, kind, identity, lane, unit, model, tokens_in, tokens_out,
tokens_cached, cost_usd, wall_s, subject, refs, body)`, WAL. The `tokens_cached`
column is added by an idempotent `ALTER TABLE ADD COLUMN` that swallows
OperationalError (telemetry.py:44-49) — that is the entire migration story.

Writer: automation/jobs/telemetry.py (capture-before-views; best-effort by
design, any fault exits 0 silently, :3-8). Readers: `GET /telemetry.json` →
telemetry_24h() (automation/dashboard-server.py:802-804); automation/jobs/telemetry-report.py;
automation/jobs/jcode-session-cost.py. Retention: none defined (section 5).

### 1.2 TSV tables (machine state)

| Table | Row shape (TAB-separated) | Writer | Readers | Retention |
|---|---|---|---|---|
| automation/research-lines.tsv | headerless 4 cols: line_id, status, last_transition, title (automation/jobs/research-routes.py:24-25) | cadence/hour/33-research-beat.sh:169, :261-280 (append + transition) | automation/jobs/research-feed.py:3-28, automation/jobs/research-routes.py:18-30 | none; lines end terminal `reviewed` |
| automation/research-dispositions.tsv | header `line action verdict reviewer evidence date support oppose followons` (research-dispositions.tsv:1; schema automation/jobs/research-routes.py:27-28) | 33-research-beat.sh review pass: terminal action adopted\|parked\|killed (:18-19) | automation/lib/research-harvest.py:1-28, automation/jobs/research-feed.py, automation/jobs/research-routes.py | none |
| automation/research-lessons.tsv | header `lesson_id date line_id subject lesson status` (research-lessons.tsv:1) | research-harvest.py:22-28 (one row per adopted disposition, keyed by line_id, idempotent) | research-feed.py:3-28 | none |
| automation/cadence-params.tsv | `key<TAB>value<TAB>provenance<TAB>note` — "the Inventory: every loop tunable lives here" (cadence-params.tsv:1-2) | operator edits (ceremony) | cadence drop-ins and jobs (e.g. automation/jobs/newspaper-edition.py) | none |
| automation/torch-ledger.tsv | consumption ledger rows (torch-ledger.tsv:1-2) | audit-station drop-in | operator | none |

State scratch tables under automation/state/ (headerless, grow-only, no retention
owner; headers read live 2026-10-04): beat-blockers.tsv `blk-<id> scope cause ts
fails active ts`; correction-sightings.tsv `token epoch`; filing-budget.tsv
`routed-key date`; gdelt-seen.tsv `epoch url`; model-demote.tsv `model 0|1 count`;
ocgo-agent-burn.tsv `utc_date session_id tool output_chars desc`;
pending-checks.tsv `id check-key desc interval ts fails pending`;
rotation-watch.tsv `name ts`; router-fed.tsv `key epoch`. Each table's writer is
its owning cadence drop-in (e.g. automation/scripts/router-tick.py owns
router-fed.tsv).

### 1.3 JSON ledgers (write-ahead state)

| Ledger | Shape | Writer | Readers | Retention |
|---|---|---|---|---|
| automation/state/report-identities.json (seam HNGH_REPORT_IDENTITIES) | `{ident: {expires, escalated}}` (automation/lib/report_queue.py:172-181) | report_queue.py:235-247 | report_queue.py dedup/escalation | forever — "terminal silence is TERMINAL" (:172-175) |
| automation/operator-approved.json | `{"approved": {id: ts}}` (automation/dashboard-server.py:206-207) | `POST /operator-item/handle\|acknowledge\|resolve\|park` (:1544-1562), atomic tmp+os.replace | operator-items-feed.py:36-37 (honored source); dashboard-server.py:682-690 (also desk-stage authz — section 5) | none |
| automation/operator-dismissed.json | same shape | `POST /operator-item/dismiss` (:1432-1453) | operator-items-feed.py:36-37 | none |
| automation/agent-handoffs.md | rows `operator-handle\|operator-dismiss\|mark-read \| <ts> \| automation\|<id> \| ...` (dashboard-server.py:204, :1226-1228, :1446, :1556) | dashboard-server.py only | operator (handoff log) | none |

Derived feeds under automation/dashboard/ (all atomic tmp + os.replace, all
rebuildable — outputs, not state): data.json `{generated_at, job, date, time,
hngh_runs, digest, breadcrumbs}` (automation/lib/common.sh:109-154, "the ONLY
dynamic dashboard artifact"); sessions.json (automation/jobs/sessions-feed.py:28-29,
from readout.json + session JSONLD); schedule.json (jobs/schedule-feed.py:27-30);
plans.json (jobs/plan-feed.py:16); history.json (jobs/history-feed.py:20,
:266-284); kb/index.json (jobs/kb-feed.py:1-20, snapshot of ~/.llm-wiki vault
paths); service-state.json (jobs/service-state.py:19); graph.json
(jobs/graph-data.py:1-45); research.json (jobs/research-feed.py:1-28);
research-routes.json (automation/jobs/research-routes.py:18-30);
operator-items.json (jobs/operator-items-feed.py:33-35); newspaper.json
(automation/scripts/newspaper-compose.py:5-21); readout.json
(scripts/dashboard-readout --json via cadence/subhour/05-readout.sh:9-20);
fleet.json (scripts/fleet-manager --json via
cadence/subhour/25-newspaper-compose.sh:18-23).

### 1.4 Markdown / link ledgers (operator-visible records)

- **docs/project/reports.md + docs/project/report-bodies/<ts>-<kind>-<id>.md +
  docs/project/report-cursor** — the report-queue ledger
  (scripts/report-queue:2-10, paths :190-194). Row header
  `| timestamp | kind | id | first line | body |` (:196); kind in
  progress|expense|optimization|scheduled|alert (:2-10); id = first 8 hex of
  sha256(text), ts = UTC ISO second (:13-16). Writer: `report-queue --add` behind
  the one shim `report(kind, text, ...)` at automation/lib/report_queue.py:225-251
  (one row per call, :105-113). Readers: control-room Reports panel via the served
  symlink automation/dashboard/reports.md → docs/project/reports.md (verified
  2026-10-04); automation/scripts/email-digest.py:405; automation/scripts/imap-poll.py:206-218;
  automation/jobs/graph-data.py. The cursor is display-advanced only
  (report-queue:60-64) via `POST /report-queue/mark-read`
  (dashboard-server.py:130-134, :1207-1228). Retention: `--prune --before --kinds
  [--archive]` (:66-73), driven by cadence/calendar/daily/02-ledger-prune.sh:1-15
  (alert/progress identity re-fire window 7d, :42-44).
- **automation/STATE.md** — derived journal export of crumbs.db
  (automation/lib/breadcrumbs.sh:10; `export --write-state`,
  crumbs-db.py:173-197). Never a source of truth.
- **~/.hngh/catalog.tsv** — produced-artifact inventory, rows
  `ts<TAB>kind<TAB>path<TAB>note`, idempotent on (kind, path)
  (automation/lib/hngh_home.py:81-104; shell twin automation/lib/common.sh:17-31).
  No retention.
- **docs/project/queue.md, docs/project/timeline.md** — plan-adjacent ledgers read
  by scripts/dashboard-readout:34-35 into readout.json (the status
  column drives queue_items, :102-114).

## 2. Data pipelines

Each hop names its producing script and its consuming script. All fetch-side hops
are poll-based on the systemd cadence (automation/cadence/README.md:2-25).

### 2.1 fetch → summarize → digest → edition

1. **Fetch** — automation/lib/sources.sh `fetch_sources`:108-135 fetches each
   configured source to `snapshots/YYYY-MM-DD/<name>-<HHMM>.json` (dir contract
   sources.sh:1-12). RSS/Atom normalized in place by `fetch_rss` (:23+), CISA KEV
   trimmed by `fetch_kev_trim` (:80+).
2. **Summarize** — automation/jobs/morning-digest.sh drives model summaries of the
   snapshots (via lib/model.sh, "never api.openai.com directly", :1-30) into
   `$DIGEST_DIR/MORNING-$DATE.md` (:15) and the cumulative `$DIGEST_DIR/$DATE.md`
   (:54-56); each step also saves `<date>.json` + `<date>-<HH>.json`. Hourly beats
   extend the same file: automation/jobs/ping-hourly.sh:17 plus
   automation/lib/digest-block.sh `append_news_block()`:26-40 (line-count gate,
   compaction roll-forward, cap 200 lines / 4000 chars).
3. **Digest** — automation/jobs/digest-public.py:1-16 writes the public dispatch
   `~/.hngh/dispatch/<date>.md` (:350) from journal + daily digests behind the
   secret scrub loader (:26-40, seam HNGH_REDACT_SECRETS); jobs/digest-local.py:1-15
   writes the local-only `~/.hngh/dispatch/<date>/index.html` + index.
4. **Edition** — automation/jobs/newspaper-edition.py:1-27 fabricates
   `~/.hngh/newspaper/<date>/` (roles desk-local/public, :12-23) from the dispatch
   parts + morning digest + manga + wallpaper. Idempotence marker edition.json
   (:11); publication window 01:30-06:30 (:55-56). automation/jobs/publication-review.py:5
   then reviews the latest dispatch edition ("keeps the future from being
   baroque").
5. **Control-room feed** — automation/scripts/newspaper-compose.py:5-21 (the
   post-cut machine: "the control-room data feed itself") merges theme.json,
   sites.json, the dispatch index, data.json digest + breadcrumbs, fleet.json and
   operator items into dashboard/newspaper.json. Refreshed every subhour tick by
   cadence/subhour/25-newspaper-compose.sh:29 (fleet.json first, :18-23, fail-soft
   keeps a stale feed serving). Consumers: automation/dashboard/map.js:324 and
   `POST /article/omp-session` (dashboard-server.py:888-924).

### 2.2 crumbs → journal → dashboard

1. Writers call `breadcrumb`/`crumb` (breadcrumbs.sh:14-25 → crumbs.py:50-64) into
   crumbs.db (section 1.1).
2. `crumbs-db.py export --write-state` appends new rows to automation/STATE.md and
   advances state_byte_offset (crumbs-db.py:173-197).
3. `update_dashboard` (common.sh:109-154) folds hngh_runs + digest + the last 60
   breadcrumbs (common.sh:145) into dashboard/data.json, atomic replace (:150).
4. automation/jobs/operator-items-feed.py — run every subhour by
   cadence/subhour/05-operator-items.sh:1-6 (fail-closed: exit 0 always) — scans
   data.json breadcrumbs plus a fresh crumbs.db query with the keyword filter
   pushed into SQL over idx_crumbs_event (:2-22), honors operator-approved.json /
   operator-dismissed.json, and writes dashboard/operator-items.json (CAP 40,
   oldest-first, :44). Item shape `{id: 8-hex of normalized text, text, first_seen,
   last_seen, status, evidence}` (:10-13); status flips to "handled" when a later
   crumb matches RESOLVED_RE (:207-210); first_seen survives reruns (:122-124).
5. Loss detection: cadence/subhour/15-crumbs-sync.sh:5-24 runs `verify --evidence`
   and files one deduped alert row per mismatch (identity `crumbs-mirror:<kind>`,
   window 0, :23-24).

### 2.3 research line → disposition → report + lessons + wiki

1. cadence/hour/33-research-beat.sh:2-30 advances the oldest non-crystallized
   research line one lifecycle transition per beat (planned → expanding →
   contracting → crystallized), commit-per-op. Each beat writes
   digest/RESEARCH-BEAT-<date>-<id>.md (:12); the crystallize transition writes the
   condensed result into kernel docs/research/<date>-<id>.md; line state lives in
   research-lines.tsv (:169-171).
2. When every line is crystallized/reviewed, the review pass runs a two-sided
   (support + adversarial) judgment and files one terminal disposition
   adopted|parked|killed into research-dispositions.tsv with the
   support/oppose/followons columns filled (33-research-beat.sh:18-19); adopted
   findings queue at most 2 follow-on subjects (fail-<date> ids).
3. Harvest: automation/lib/research-harvest.py:1-28 turns each adopted disposition
   into exactly one research-lessons.tsv row keyed by line_id (re-disposition
   refreshes; a later non-adopted disposition retires it) and appends
   wiki/sources/LES-<line_id>.md when a ~/.llm-wiki vault is mounted (hngh never
   writes meta/ or raw/). Fail-closed on malformed headers, idempotent on
   unchanged rows (:22-28).
4. Read side: automation/jobs/research-feed.py:1-28 merges lines, dispositions,
   lessons and sources into research.json;
   automation/jobs/research-routes.py:18-30 derives research-routes.json
   (tri-state 1/0/null edge buckets, orphan nodes);
   automation/scripts/email-digest.py composes the research section (seam
   HNGH_DIGEST_RESEARCH).

### 2.4 run/spend telemetry

Emit → ~/.hngh/db/telemetry.db (automation/jobs/telemetry.py:21-27). Read side:
automation/jobs/telemetry-report.py, `GET /telemetry.json`
(automation/dashboard-server.py:802-804), automation/jobs/jcode-session-cost.py,
and the budget
section of automation/scripts/email-digest.py (seam HNGH_DIGEST_TELEMETRY).
Best-effort end to end: the emitter exits 0 on any fault (telemetry.py:3-8).

### 2.5 queue/timeline → readout → session + schedule panels

scripts/dashboard-readout --json reads docs/project/timeline.md +
docs/project/queue.md (:34-35); `queue_rows()` keeps rows whose status is
queued|done|active and counts rows without a status as done (:102-114). Producers:
cadence/subhour/05-readout.sh:9-20 (per-PID tmp then mv, self-gated to one run per
1800s by a /tmp stamp, :5-8) and automation/jobs/refresh-dashboard.sh:14-25.
Consumers: jobs/sessions-feed.py:28 and jobs/schedule-feed.py:27 (both also read
session JSONLD files).

### 2.6 inbox → operator items + report annotations (bidirectional email)

automation/scripts/imap-poll.py:1-21 reads the notify-email account's UNSEEN
mail. Plain operator requests become operator items via
automation/lib/operator-item.sh:1-13; a `[hngh <report-id>]` subject annotates
the matching report body sidecar (docs/project/report-bodies/<ts>-<kind>-<id>.md)
and applies directive grammar to matching open items (approve: → handled, deny: →
dismissed, note:/unknown → annotation only); plan-decision replies write a
plan-proposal DRAFT under automation/digest/ and nothing is ever auto-accepted
(:10-13). The read leg never touches docs/project/reports.md and never deletes
anything (:216); an unresolvable password fails closed (:35). Outbound:
automation/lib/notify-email.sh + automation/scripts/email-digest.py (the 57-digest-send
beat in jobs/ping-hourly.sh:17).

## 3. Message buses + routes

There is no broker. Four poll-based surfaces play the bus role, each with its own
delivery contract. Everything is at-least-once at the file level and deduplicated
at the row level.

### 3.1 The buses

**Report queue bus** — docs/project/reports.md + report-bodies/ + report-cursor
(section 1.4). Producers: report_queue.py `report()`:225-251 (one row per call,
:105-113), `gate_refusal()` (breadcrumbs.sh:30-40: one crumb + one deduped row),
lib/operator-item.sh:10-13, and the dashboard POST handlers (the owed report row
is filed BEFORE the ledger write, dashboard-server.py:1564-1577). Semantics:
identity dedup — same kind + identity within a window (default 86400s, 0 =
unlimited) collapses to a ` ×N` marker instead of a new row (:27-39);
`--evidence TOKEN` suppresses stale re-fires until the token changes (:41-48);
terminal silence — each identity carries expires (default first-seen + 7d), one
`expired:<ident>` escalation fires, then the lane goes silent until re-armed
(report_queue.py:115-120, :235-247). Fail-closed advisory semantics: a lost row
returns False, never a crash (:112-113, :221-222); file faults exit 2
(scripts/report-queue:78-80); a missing cursor reads as all-unread (fail-open,
:60-64).

**Crumbs journal bus** — crumbs.db + STATE.md export (section 1.1). Single write seam
(crumbs.py:50-64), WAL + BEGIN IMMEDIATE (crumbs-db.py:149-168), export as an
append-only fence (:173-197). Fail-open: writes are lost silently on fault
(:330-331) — the mirror verify alert (15-crumbs-sync.sh:23-24) is the only loss
detector. Consumers: every keyword scanner, the dashboard breadcrumb slice
(common.sh:145), and the operator-items feed.

**Operator-item lifecycle bus** — the three channels a job may speak, documented
at operator-items-feed.py:2-22: a report-queue row (lib/report_queue.py), an alert
row + notify-email.sh, or `operator_item()` = both plus a crumb
(lib/operator-item.sh:1-13, "the alert row is the report-queue contract; the
alert crumb is what jobs/operator-items-feed.py reads", :6-7). State transitions
ride `POST /operator-item/{handle,dismiss,acknowledge,resolve,park}` (body {id,
note}; note <=200 chars and required for park; dunder ids banned —
dashboard-server.py:1455-1470): each call files its report row first, then
appends the agent-handoffs.md line and atomically rewrites operator-approved.json
/ operator-dismissed.json (:1432-1453, :1544-1562). Email directives and
keyword-derived items enter the same lane (imap-poll.py:18-21;
operator-items-feed.py keyword scan).

**Dispatch/newspaper edition bus** — published files under ~/.hngh/dispatch/<date>
and ~/.hngh/newspaper/<date>/; publication is idempotent per date via the
edition.json marker (newspaper-edition.py:11) inside the 01:30-06:30 window
(:55-56). Pull-based consumers: publication-review.py:5, newspaper-compose.py:5-15,
and the /digest* HTTP routes (dashboard-server.py:842-846).

### 3.2 Delivery timing

Tiers come from systemd only (automation/cadence/README.md:2-25): subhour every
minute (hngh-cadence-subhour.timer:5 `OnCalendar=*:*:00`), hour hourly at :00:10
(hngh-cadence-hour.timer:5), calendar 05:00 daily / Mon 06:00 weekly / 1st 06:00
monthly (hngh-cadence-calendar.timer:5-8, Persistent=true — calendar catches
missed runs; subhour never catches up, "per-minute catch-up bursts are worse than
a skipped tick", README:10-15). Stamp files in /tmp pace self-gated drop-ins
(README:17-25; e.g. 05-readout.sh:5-8 = one run per 1800s). Every drop-in honors
the lib/env.sh seams so tests point at fixture homes/roots, never the real
machine (README). The dashboard itself is a long-lived systemd service
(hngh-dashboard.service:6-13, Restart=on-failure).

### 3.3 Route table — producer → transport → consumer → end-form

| Producer | Transport | Consumer | End-form |
|---|---|---|---|
| lib/sources.sh fetch_sources:108-135 | snapshots/YYYY-MM-DD/<name>-<HHMM>.json | jobs/morning-digest.sh:84-105 | MORNING-<date>.md |
| jobs/morning-digest.sh:54-56 + jobs/ping-hourly.sh:17 (lib/digest-block.sh:26-40) | $DIGEST_DIR/<date>.md | jobs/digest-public.py:350, jobs/digest-local.py:1-15 | ~/.hngh/dispatch/<date>.md + <date>/index.html |
| jobs/digest-public.py + digest-local.py | ~/.hngh/dispatch/<date>/ | jobs/newspaper-edition.py:15-23 | ~/.hngh/newspaper/<date>/ (edition.json marker) |
| jobs/newspaper-edition.py + data feeds | dashboard/newspaper.json (automation/scripts/newspaper-compose.py:5-21 via cadence/subhour/25-newspaper-compose.sh:29) | automation/dashboard/map.js:324; POST /article/omp-session (dashboard-server.py:888-924) | control-room map; article desk pkg ~/.hngh/dispatch/<date>/<aid>.context.md |
| lib/crumbs.py:50-64 | state/crumbs.db (WAL) | crumbs-db.py export:173-197; common.sh:145 | STATE.md; data.json breadcrumbs |
| jobs/operator-items-feed.py:2-22 | crumbs.db + data.json + operator-*.json | dashboard/operator-items.json (CAP 40, :44) | control-room attention rows; newspaper operator desk |
| lib/report_queue.py:225-251 | docs/project/reports.md + report-bodies + report-cursor | app.js:411-440; automation/scripts/email-digest.py:405; automation/scripts/imap-poll.py:206-218 | control-room Reports; daily email; mail annotations |
| cadence/hour/33-research-beat.sh:169-280 | research-lines.tsv → research-dispositions.tsv | lib/research-harvest.py:22-28; jobs/research-feed.py:1-28 | research-lessons.tsv + wiki/sources/LES-*.md; research.json |
| automation/jobs/research-routes.py:18-30 | research-routes.json | GET /research-routes.json (dashboard-server.py:814-816) | Routes map |
| scripts/dashboard-readout:102-114 | readout.json (05-readout.sh:9-20, 1800s gate) | sessions-feed.py:28, schedule-feed.py:27 | sessions.json, schedule.json panels |
| scripts/fleet-manager --json:1-25 | dashboard/fleet.json (25-newspaper-compose.sh:18-23, fail-soft stale) | GET /fleet.json (dashboard-server.py:820-825, cached 30s, :452-453) | control-room fleet node |
| jobs/telemetry.py:21-27 | ~/.hngh/db/telemetry.db | telemetry_24h (dashboard-server.py:802-804); jobs/telemetry-report.py | /telemetry.json; email budget |
| POST /operator-item/* (dashboard-server.py:1432-1562) | agent-handoffs.md + operator-*.json + report row | jobs/operator-items-feed.py:36-37 | desk handoffs; handled marks |

Optimizations already on these routes: the keyword filter pushed to SQL over
idx_crumbs_event (operator-items-feed.py:2-22); one fleet-manager invocation per
tick with a 30s server-side cache (dashboard-server.py:452-453); per-PID tmp + mv
for readout so concurrent ticks never tear (05-readout.sh:9-20); digest blocks
capped at 200 lines / 4000 chars (digest-block.sh:26-40) and the data.json digest
folded to 20000 chars on a whitespace boundary (common.sh:134); breadcrumb export
sliced to the last 60 rows (common.sh:145); atomic os.replace wherever a feed is
rewritten (common.sh:150, crumbs-db.py:173-197).

## 4. End-forms

The operator-visible artifacts and the pipeline that feeds each.

| End-form | Where | Fed by |
|---|---|---|
| Control room | http://<host>:8890 (ThreadingHTTPServer 0.0.0.0, dashboard-server.py:1919-1923; hngh-dashboard.service:6-13) | every route below |
| Overview | data.json | crumbs→journal→dashboard (section 2.2) + hngh_runs |
| Reports panel | reports.md + report-cursor served via symlink (automation/dashboard/reports.md → docs/project/reports.md) | report queue bus (section 3.1); unread = rows after cursor, unknown cursor = all (app.js:411-440) |
| Map | newspaper.json (map.js:324), fleet.json | control-room feed hop (section 2.1.5) + fleet route |
| Routes / Research | research-routes.json, research.json | research pipeline (section 2.3) |
| Triage / Queue / Timeline | readout.json | readout pipeline (section 2.5) |
| Sessions / Schedule / Plans / System / History / KB | sessions.json, schedule.json, plans.json, service-state.json, history.json, kb/index.json | feed producers section 1.3; plans.json is fail-soft (refresh-dashboard.sh:35) |
| Digest pages | /digest/<name>.md + /digest-html/<name>.html (dashboard-server.py:842-846) | ~/.hngh/archive/digest (DIGEST_DIR, common.sh:15) |
| Telemetry | /telemetry.json (dashboard-server.py:802-804) | telemetry pipeline (section 2.4) |
| Article desk packages | ~/.hngh/dispatch/<date>/<aid>.context.md (dashboard-server.py:888-924) | POST /article/omp-session over newspaper.json articles |
| Daily public dispatch | ~/.hngh/dispatch/<date>.md (digest-public.py:350) | digest pipeline (section 2.1) |
| Local dispatch edition | ~/.hngh/dispatch/<date>/index.html (digest-local.py:1-15) | digest pipeline (section 2.1) |
| Newspaper edition | ~/.hngh/newspaper/<date>/ (newspaper-edition.py:15-23) | edition bus (section 3.1) |
| Operator email digest | automation/scripts/email-digest.py:1-24 (reading order TL;DR → operator items → progress → research → commits → alerts → budget → footer), sent by the 57-digest-send beat (jobs/ping-hourly.sh:17) | report queue + research + telemetry |
| Mail reply loop | IMAP UNSEEN → items/annotations (imap-poll.py:1-21) | operator-item lifecycle bus |
| Journal | automation/STATE.md (crumbs-db.py export:173-197) | crumbs journal bus |
| Archive | ~/.hngh/archive/{digest,crumbs-archive.tsv} (hngh_home.py:62-69) | retention owners section 1.1 |
| Wiki / KB | ~/.hngh/wiki (hngh_home.py:41-44), ~/.llm-wiki source pages (research-harvest.py:1-28), kb snapshot dashboard/kb/index.json | research harvest |
| Artifact inventory | ~/.hngh/catalog.tsv (hngh_home.py:81-104) | hngh_catalog() callers (common.sh:17-31) |

Auth boundary: the control room takes a Bearer token from ~/.hngh-dashboard-token,
generated locked at first run, constant-time compared, 300-char cap, passfile read
fail-closed (dashboard-server.py:6-15, :406-419).

## 5. Gaps

Named-but-absent pieces, stated plainly:

1. **No schema registry.** Every schema is an inline string in its writer
   (crumbs-db.py:38-46; telemetry.py:25-27) or an implicit TSV column order
   (automation/jobs/research-routes.py:23-28). Nothing validates a reader against a writer's
   shape except research-harvest.py's fail-closed header check (:22-28).
2. **No schema migration story.** The only migrations are try-ALTER-and-swallow
   (telemetry.py:44-49; crumbs-db.py:68-88 writer column + one-time `[w=@]` stamp
   split). A column rename or TSV shape change would break readers silently.
3. **The buses are poll-based files, not queues.** No push, no per-consumer
   offsets: the report cursor is one shared display cursor (report-queue:60-64),
   and every other consumer rescans full state each tick (operator-items-feed.py
   full scan, CAP 40 at :44). Delivery is at-least-once with row-level dedup
   windows, not ordered handoff.
4. **One dead hop in the digest path.** `update_dashboard` reads
   "$AUTOMATION_ROOT/digest/MORNING-$day.md" and "$AUTOMATION_ROOT/digest/$day.md"
   (common.sh:115-116) while the writers land in $DIGEST_DIR =
   ~/.hngh/archive/digest (common.sh:15; morning-digest.sh:15; ping-hourly.sh:17).
   Observed 2026-10-04T11:00:56Z: live data.json digest length 0. Until repointed,
   data.json carries breadcrumbs but no digest. (automation/digest/ is a separate
   runtime dir for research-beat artifacts and IMAP plan drafts,
   33-research-beat.sh:12, imap-poll.py:10.)
5. **Fail-open writers lose writes silently.** crumbs-db.py exits 0 on any fault
   (:330-331); report_queue.py swallows a lost row as False (:221-222). Only the
   crumbs verify/mirror alert (15-crumbs-sync.sh:23-24) polices loss; the report
   queue has no equivalent detector.
6. **operator-approved.json has two contracts.** It is both the desk-stage authz
   store (dashboard-server.py:682-690) and the operator-item handled ledger
   (:1544-1562). One file, two meanings: a ceremony edit for one purpose silently
   moves the other.
7. **No retention owner** for telemetry.db, operator-approved.json /
   operator-dismissed.json, agent-handoffs.md, catalog.tsv, or any
   automation/state/*.tsv table. Only crumbs (14d rotate, alert/finding/decision
   forever, crumbs-db.py:264-300) and reports (02-ledger-prune.sh:1-15) are
   pruned.
8. **Telemetry location mismatch in the record.** The telemetry.py docstring says
   dashboard/telemetry.db while the code writes ~/.hngh/db/telemetry.db
   (telemetry.py:21-24); anyone reading the docstring alone will query an empty
   store.

This document covers schemas, pipelines, the bus role as actually played, the
route table and the end-forms. It does not propose a replacement transport: that
is a separate design decision, and the honest state today is that the ledgers
themselves are the bus.
