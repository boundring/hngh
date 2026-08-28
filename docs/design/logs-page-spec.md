# Logs page

Logs are an operator's evidence surface: slices with status and next action,
not a raw transcript. The tab already has the two raw layers (reports feed,
digest text); the work is structure, not more lines.

Status: DESIGN — known-good log-presentation patterns (12-factor event
streams, structured events, severity/facet filtering, rate histograms,
retention tiers, redaction) mapped onto the dashboard's Logs tab, from the
dashboard-QoL plan, 2026-08-28.

Source: `../../research/2026-08-28-log-presentation-patterns.md` (primary);
hngh-automation `dashboard/index.html`, `dashboard/app.js`,
`lib/common.sh` (`update_dashboard`), `lib/breadcrumbs.sh`,
`jobs/morning-digest.sh`; the REVIEW-2026-08-28 P1 on the stale digest feed.

Cross-links: [ledger-and-records-spec.md](ledger-and-records-spec.md)
(the data half — its §4 already names this view),
[knowledge-base-spec.md](knowledge-base-spec.md),
[presentation-boundary.md](presentation-boundary.md),
[display-register-spec.md](display-register-spec.md).

## 1. Where the tab stands

`#p-logs` hosts three layers, all render-only over two feeds. The ops strip
(`#logs-ops`) shows the operator-items feed (`dashboard/operator-items.json`
+ `dashboard/operator-dismissed.json`, dismiss via `POST
/operator-item/dismiss`) with open/handled status, age chips, and a dismiss
button per item; it degrades to plain digest bullets when the feed is
unavailable. The `#lt-reports`/`#lt-digest` toggle switches between
`#logs-reports` (the last 60 breadcrumbs from `data.json`, newest-first,
hard-capped at 40 shown) and `#logs-digest` (the whole `digest` string as one
`<pre class="digest">`). `#logs-sum` carries the counts. The page is a pure
reader — fetch-and-render, no governance input — and that boundary is
non-negotiable for everything below.

## 2. Event stream, not transcript (twelve-factor)

The twelve-factor position is that an app writes event streams and does not
manage their routing. Today the tab's default view is the opposite of that:
`#logs-digest` renders one 20,000-character-capped markdown string
(`digest/MORNING-<date>.md` + today's ping digest, concatenated by
`update_dashboard`) as an undifferentiated wall. The actual event stream
already exists and is the better default: the breadcrumb rows
(`{ts, job, event, detail}` written by `lib/breadcrumbs.sh` into
`STATE.md`, shipped as `data.json .breadcrumbs`). Change note: flip the
default sub-view to Reports (events) and treat Digest as the curated daily
layer it is — a `sessionStorage` default plus honest labels, not new data.
The app still does no routing: it renders whatever `update_dashboard`
regenerated last.

## 3. Structured events and the logging contract

The breadcrumb contract is four pipe-separated fields with `|` escaped as
`¦` — structure at write time, exactly the contract the research line
demands. What it lacks is any severity or correlation field: `data.json`
rows carry only `ts`, `job`, `event`, `detail`. The event vocabulary is real
and stable (STATE.md's dominant values: `alert`, `mounted`, `tick-done`,
`tick`, `steer`, `dash-check`, `lint-identifiers`, …) but its meaning lives
in the writer's head. Change note: the feed must add structure, the UI
cannot synthesize it — `breadcrumbs.sh`/`update_dashboard` gain an optional
severity column (or a small job→severity mapping beside the existing event
table) and, where it exists, a subject/identity (the hngh run id a `hngh`
breadcrumb belongs to). Until the feed adds it, the tab must not guess.

## 4. Severity/facet filtering — the regex must die

`renderReports` currently invents severity with two hard-coded regexes:
`/CRITICAL|alert|failure/i` → `alert` class, `/NOTABLE|steer|done/i` →
`notable`. These straddle two vocabularies — `CRITICAL:`/`NOTABLE:` are
digest bullet tiers from `build_prompt`'s summarization contract, while
`alert`, `steer`, `tick-done` are breadcrumb events — so a digest tier name
matching an event is coincidence, not classification. Change note: once §3
ships a severity field, replace both regexes with a facet chip row in the
reports header (chips for each severity, plus a job facet — `job` is already
a real field — and a text filter over `detail`), and let the class on each
`.crumb` row come from the field. The unread counter in `#logs-sum`
 switches from regex hits to severity-filtered hits. No facet state leaves
the page — display only.

## 5. Slices, not lines

The research line's primary unit is a bounded evidence slice around a run,
job, or failure window. The tab's closest existing slice is `#logs-ops`:
each operator item already carries id, status, first-seen age, text, and
evidence — the operator's "what needs me and since when." The reports list
is not yet a slice: 40 flat rows. Change note: group `#logs-reports` rows by
job (and by hngh run id once §3 lands it) into collapsible groups with the
group's worst severity and row count on the header; a group header is the
slice, the rows beneath are the engineer's drill-down (exact sequence,
details — the roles split from the research findings §5). This is grouping
of data the feed already emits; no new producer.

## 6. Rate histograms

The ledger spec (§4) already reserves an event-rate histogram for this view,
gated on the telemetry store existing. Today it cannot be drawn from
`data.json`: the feed ships only the last 60 breadcrumbs and drops the rest
on every `update_dashboard` call, so no client-side histogram can be honest
about anything but the last few minutes. Change note: the histogram reads
`dashboard/telemetry.db` (the `events` table, per-source/per-kind counts
bucketed by hour) through a small generated feed alongside the other
`*-feed.py` writers — uPlot, per the ledger spec's stage-6 note. Until that
feed lands, the tab shows nothing in its place rather than a histogram of
the visible 60 rows.

## 7. Retention tiers

The tiering decision is the ledger spec's (§2: raw 7d, rollups 90d, curated
permanent in git); this view's job is to inherit it, not invent a second
policy. Grounding: `STATE.md` grows unboundedly — REVIEW-2026-08-28 flags
minute-tier ticks appending thousands of rows — while `update_dashboard`
keeps only the last 60 breadcrumbs per write, so the dashboard's window is
already retention-limited by accident, not policy. `operator-dismissed.json`
is an unbounded per-id ledger with a "dismissed today" count. Change note:
the raw tier's retention is enforced at the producer (STATE.md rotation or
its telemetry-store successor), and the dismissed ledger gets an age-out;
the tab then states its window honestly in `#logs-sum` ("last 24h of
events") instead of "60 entries". No client-side retention logic.

## 8. Redaction

Two paths feed this tab, with different exposure: breadcrumbs are operator
and job-authored lines (pipes escaped, nothing else), and the digest is
model output over fetched public sources. Credentials and operator paths
must never reach either. Change note: redaction happens at the feed
boundary, inheriting the credential pattern from the kernel's
`scripts/verify-candidate.py`, per the ledger spec — a single scrub on write
in `update_dashboard` (and the breadcrumb writers), never a client-side
filter that leaves the raw file on disk unredacted. The operator-items feed
keeps its existing shape; its `text`/`evidence` fields pass through the same
scrub.

## 9. Non-goals

Design only — implementation rides a later build wave and this file carries
no code changes. Explicitly out of scope here: the telemetry store and its
producers (ledger spec §3, must land before §6), any governance use of
anything this tab renders (the page stays display-only), log shipping or
external aggregators (twelve-factor: hngh-automation writes streams, the
dashboard renders them), and raw journald surfaces in the tab.
