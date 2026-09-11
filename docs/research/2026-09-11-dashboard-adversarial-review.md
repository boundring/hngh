# Dashboard adversarial review -- interactivity census + QoL direction

Status: research, 2026-09-11. Read-only audit of `automation/dashboard/` +
`automation/dashboard-server.py` as served today (:8890 live, probed twice,
GET only). Asks the operator's three questions: how interactive is it NOW,
how much more interactive SHOULD it be, and what pairs with the layout
directive "tighter, smaller-margins, more-text-clearly-visible, top-flowing
and auto-resizing content". Implementation is a later beat; nothing here is
a plan file.

Adversarial stance per
[2026-08-28-adversarial-review-patterns.md](2026-08-28-adversarial-review-patterns.md):
state clarity over polish, fresh-eyes, no victory laps. Bar-setting prior
art: [2026-08-26-dashboard-design-notes.md](2026-08-26-dashboard-design-notes.md)
(borrow-list largely landed: one-panel-per-tab, visible-by-default, stat
cards, gantt-as-time) and
[2026-08-26-evolutionary-ui-loop.md](2026-08-26-evolutionary-ui-loop.md)
(measure, don't taste -- findings below are file:line-grounded, the vision
loop should grade the result).

## 1. Interactivity census

### Server surface (automation/dashboard-server.py)

Reads (GET):

| Route | Behavior | Lines |
| --- | --- | --- |
| `/*` static | SimpleHTTPRequestHandler rooted at `dashboard/` -- every feed JSON is a plain file fetch | :190-192 |
| `/hngh-docs/research/<name>.md` | jailed single-doc serve, strict name regex + realpath jail | :200-221 |
| `/digest/<name>.md` | same jail over `dashboard/digest/` | :204-205, :120-121 |

Writes (POST, dispatch :232-241) -- ten handlers, all advisory/display-only
per the module docstring :2-10, no shared token (:322-329):

| Route | Purpose | UI caller today |
| --- | --- | --- |
| `/operator-item/dismiss` | handoffs ledger + `operator-dismissed.json` | YES app.js:154-163 |
| `/api/feedback` (+ `feedback`) | feedback capture, 1/s/type guard | YES feedback-view.js + email forms |
| `/research-line` | append proposal lane to backlog.md | YES research-view.js:394 |
| `/research-note` | backlog annotation, optional steer | YES research-view.js:405 |
| `/system/refresh` | re-run feed probe | YES system-view.js:288 |
| `/system/reset-failed` | systemctl --user reset-failed | YES system-view.js:313 |
| `/system/backup-now` | governed config-backup lane | YES system-view.js:328 |
| `/spawn` | desktop launcher spawn (display-only) | **NO served-JS caller** |
| `/tile` | window tiling (display-only, 403-guarded) | **NO served-JS caller** |
| `/flag` | handoffs flag row | **NO served-JS caller** |

Ledger corroboration (agent-handoffs.md first-field counts): operator-dismiss
17, system-op 1, spawn 0, tile 0, flag 0. The POST surface the UI exercises
is exactly 7 of 10; the 3 orphans are all in plan
`2026-09-09-stall-recovery-and-operator-surfaces.plan.md` step 5
("Rebuild the orphaned write-surface UI") -- status `accepted`, zero checkboxes
ticked: **NOT landed**. Same plan's step 6 (token guard on POST, fix
`0.0.0.0:8890` binding) also unlanded; the docstring still blesses the
token-less LAN posture.

### Client fetch model (what actually moves over the wire)

| View | Feeds | Cadence | Source |
| --- | --- | --- | --- |
| app.js core | operator-items.json, operator-dismissed.json, data.json, readout.json | 10s, unconditional | app.js:13, :511-516 |
| SessionsView | **sessions.json, 2.1 MB whole** | 15s while mounted | sessions-view.js:21, :458 |
| ScheduleView | schedule.json + readout.json 60s; **sessions.json once at init**; time-ledger.json | 60s | schedule-view.js:32, :302, :307 |
| SystemView | system-ops.json | 60s | system-view.js:379 |
| ResearchView | research.json + per-doc probes | 60s | research-view.js:35, :371 |
| KBView | kb/index.json + per-doc md on open | none (activation refresh) | kb-view.js:360, :386 |

No SSE, no websocket, no backoff, no `visibilitychange` pause, no
conditional GET (every fetch is `cache: 'no-store'`). The only server-side
data API is the filesystem; there is no query param, filter, page, or
range anywhere. A 15s poll of sessions.json is ~140 KB/s per open tab,
forever, growing with session count (39 sessions / 1,933 entries today,
biggest 194 entries).

### Feed sizes and row counts (measured 2026-09-11)

- plans.json: **170 plans**, plans-view renders all rows oldest-first.
- research.json: 42 campaign lines + 4 backlog lanes + 39 design docs +
  9 open questions.
- operator-items.json: 40 items (open + handled mixed).
- data.json: 60 breadcrumbs + 7.5 KB digest text.
- schedule.json: 61 recurring + 19 one-off lanes.
- sessions.json: 2,169,357 bytes, largest single session 194 entries.
- telemetry.db: `events` table, 534 rows (ts, kind, model, tokens_in/out,
  **cost_usd**, wall_s) -- written by jobs/telemetry.py, context-ratio,
  session-cost, ocgo-attribution; **no dashboard view consumes it at all**.

### Verdict of the census

This is a **read-only mirror with seven reachable mutations** -- better than
the classic "dashboard = screenshot" failure, and the newest interactive
slice (feedback, commits 43b97e6 + 9c9f2d0, 2026-09-11) is fully wired.
Ranked gaps, biggest first:

1. The operator's manual-session control (spawn form + tile button, the
   stated need behind plan step 5) exists server-side and has no button.
2. No push: every state change reaches the operator via 10-60s polling of
   whole files, including a 2.1 MB transcript blob every 15s.
3. Zero server-side data shaping: 170-plan table, 39-doc lists, 60-crumbs
   all arrive whole; only client-side filtering exists, and the Plans tab
   (the densest table) has none at all.

## 2. Adversarial findings (ranked)

F1. **sessions.json is the whole pipe, 15s, forever** --
    sessions-view.js:458 fetches all 2.1 MB on a 15s timer
    (sessions-view.js:21) and schedule-view.js:302 fetches it a second
    time at init just for bar-to-session deep links. Two tabs double it.
    The feed grows monotonically; nothing trims or slices. This is the
    single largest load item on the page by two orders of magnitude.

F2. **Dead link on the landing view** -- overview-view.js:121 renders
    `<a href="/digest/<today>.md">full dispatch</a>` unconditionally
    whenever digest text exists, but `dashboard/digest/` does not exist
    on disk today, so the route 404s. Research-view probes its result
    docs first and renders no link on 404 (research-view.js:161-179,
    fail-closed); the overview link skips that discipline. Fresh-eyes
    failure mode: first click on the landing view is a dead end.

F3. **No auth token on ten POST endpoints at 0.0.0.0:8890** --
    dashboard-server.py:592 binds all interfaces; :322-329 documents the
    no-token posture as acceptable for a LAN static dashboard. Plan
    2026-09-09 step 6 already flagged this ("phone-accessible on LAN") and
    prescribed a shared token or a tailscale-bound socket. Still unlanded.
    Any device on the LAN can dismiss operator items, spawn desktop
    windows, and run reset-failed.

F4. **Plans tab is a 170-row table with zero affordances** --
    plans-view.js:40-65 renders feed.plans verbatim: oldest-first
    (2026-08-28 ... 2026-09-11), no search, no sort, no status filter, no
    link to the plan file. Logs (app.js:309-400) and KB (kb-view.js:210)
    both have text filters; Plans -- the table an operator actually scans
    at queue rotation -- has nothing. Also the only major list that flows
    oldest-first, against the top-flowing directive.

F5. **The refresh button lies** -- bindPanels wires it to app.js `load()`
    only (app.js:579), so it refreshes digest/reports/operator-items but
    NOT the mounted view's own feed (plans, research, schedule, sessions,
    system, kb each own their fetch). An operator who clicks refresh on
    the Sessions tab gets a 10s-old sidebar and thinks it is current.

F6. **Polling never sleeps** -- every timer (app.js:724, sessions-view.js:530,
    schedule-view.js:314, system-view.js:379, research-view.js:371) runs on
    `setInterval` with no visibilitychange pause and no backoff after a
    failed fetch. A background tab on a laptop burns the 2.1 MB fetch at
    full cadence; a down server hammers 4 fetches per 10s and renders
    nothing useful.

F7. **Contrast failure baked into the palette** -- `--dim: #484f58`
    (style.css:5) on `--bg: #0d1117` measures **2.28:1** (computed).
    `--dim` is the color of `.cts` timestamps (style.css:56), counters
    (:77, :274), `.missing-note` (:195), `.cdetail` fallbacks, and the
    age chips' quieter text -- 10.5-11px body copy below WCAG AA (4.5:1)
    and below the 3:1 large-text floor. `--muted` (#99a3ae, 6.76:1) is
    compliant; `--dim` is not. A `2026-09-11-routed-ui-audit-axe` plan
    already exists in the ledger -- this is its ammunition.

F8. **Keyboard support is half an ARIA implementation** -- tabs carry
    `role="tablist"`/`tabpanel` (index.html:29-39) but activate() never
    moves focus and there are no arrow-key bindings (app.js:677-697); the
    panel `<section>`s are tab-panels whose content is unreachable by the
    documented pattern. `/` and Escape work only inside Schedule
    (schedule-view.js:273-280). Sessions detail has tabindex=0 but no
    scroll keys beyond the browser default. No skip link, though the
    header/tab DOM order is sane.

F9. **Transcript re-render cost per keystroke** -- the session filter
    input re-renders the entire selected transcript (sessions-view.js:505-509
    -> renderDetail full innerHTML rebuild at :425), re-running the regex
    highlighter over up to 194 entries per keystroke. No debounce, no
    incremental DOM. Fine at 20 entries; already noticeable at 194.

F10. **telemetry.db is invisible money** -- 534 event rows carry
     cost_usd/tokens/wall per model and lane; the operator reads spend
     today only through digest prose and budget.md. A one-number cost row
     plus a 24h sparkline would answer "what did last night cost" at a
     glance (the design-notes borrow-list's stat-panel pattern).

F11. **Feedback loop is a black hole to its own authors** -- the pipeline
     is real (POST -> feedback/*.json -> feedback-ingest.py ->
     operator-items; feedback-apply.py auto-applies [quick] theme/format
     requests), but the dashboard shows nothing about submitted items'
     fate: no "your feedback" list, no processed marker. The dismissal
     surface got an honest arm/confirm (app.js:112-121); feedback got
     fire-and-forget.

F12. **Layout directive vs measured reality** -- see section 4; summary:
     spacing is already tighter than most dashboards (3px table cells,
     5px header) but the landing view caps itself at 1100px inside a
     1440px shell, --dim text is unreadably low-contrast, and Plans/
     Research tables flow oldest-first.

## 3. QoL backlog (ranked by operator-value / effort)

"NEW server" = needs a dashboard-server.py or jobs/ change; everything
else lands UI-only. Governance note: every item stays inside the already-
permitted write families (feedback, dismiss, advisory research prose,
display-only system ops, desktop spawn/tile) -- see section 5.

| # | Item | Consumer it serves | Server? | Effort |
| --- | --- | --- | --- | --- |
| B1 | Plans tab: search box + status filter chips + sort (newest-first default), link each slug to its plan doc | operator at queue rotation; plans-view.js:40-65 | no (doc links reuse the research-doc jail pattern, P2) | S |
| B2 | Fix the overview "full dispatch" dead link: probe `/digest/<today>.md` first, render link only on 200 (copy research-view's probe) | everyone on the landing tab | no | XS |
| B3 | Refresh button refreshes the mounted view too; pause all timers on `visibilitychange` hidden; exponential backoff after failures | everyone, laptop users | no | S |
| B4 | Spawn + tile controls in the Sessions sidebar: per-row "tail" launcher button (names a launcher key, POST /spawn), toolbar tile button for selected sessions (POST /tile, 403-honest when disabled) | the orphaned plan step 5; manual-session control | no (endpoints exist) | S |
| B5 | Server-side session slicing: `GET /session/<id>?tail=N` (or `sessions.json?session=&tail=`) so SessionsView polls kilobytes, not 2.1 MB | everyone; sessions-view.js:458, schedule-view.js:302 | **YES** | M |
| B6 | Live push for the attention surface: one SSE endpoint streaming operator-items + verdict mtime changes; app.js drops its 10s poll when connected | operator away-from-desk; app.js:13 | **YES** | M |
| B7 | Telemetry stat row: 24h cost + tokens + runs from a new `dashboard/telemetry.json` emitted by a telemetry-report pass; one big number + 24h sparkline (stat-panel pattern) | spend awareness; F10 | **YES** (feed only; view is UI) | M |
| B8 | Report-queue read state in Logs: expose `--mark-read` (cursor advance) and unread count as a chip; `--prune` stays CLI (destructive) | report queue triage | **YES** (one POST, handoffs-logged) | S |
| B9 | Contrast token fix: raise `--dim` to >= 4.5:1 (#6e7681 measures ~5.9:1) | every timestamp/counter | no | XS |
| B10 | Expandable plan rows -> plan doc via jailed `GET /hngh-docs/plans/<slug>.plan.md` (clone :200-221 for the plans dir) | queue rotation drilldown | **YES** | S |
| B11 | Keyboard: arrow-key tab roving + focus move on activate; `/` focuses the Logs text filter globally; skip-link to main | keyboard operators | no | S |
| B12 | Density toggle: one CSS var (`--row-pad`) with comfortable/compact chips in the header; tables + crumbs respond | screen-half operators | no | S |
| B13 | Tab-title attention badge (`document.title = "(3) hngh"`) when open operator items > 0 | multi-window operators | no | XS |
| B14 | Feedback receipt: after POST, show last 5 submitted items + applied-status chip (reads feedback/processed/) | feedback authors | no | S |

Explicitly deferred (ponytail, see section 6): virtualization, websocket
bidirectional layer, component framework, per-panel drag layouts.

## 4. Layout direction (the directive made concrete)

Directive: "tighter, smaller-margins, more-text-clearly-visible,
top-flowing and auto-resizing content". Register law: display-register-spec
sections 2-4 (state-driven captions, evidence first, existing palette owns
the colors; no invented hexes, optional aliases never canonical). The
dashboard already complies on voice (one caption per state: the verdict
pill + LCD ticker, app.js:285-288) and on palette discipline (all six
tokens in style.css:2-6 predate the spec; nothing invented). What follows
is the compliance audit and the tightening rules.

### Measured spacing today (style.css unless noted)

- Header: 5px 8px padding, 1px line, sticky (:10-16) -- already tight.
- Content: `#grid` padding 0 20px 32px (:504); `.p-body` 4px 12px 12px
  (:120); table cells 3px 6px (:125); panel gap 10px (:109).
- Landing view: `.ov { max-width: 1100px }` (overview-view.js:36) inside a
  `--content-max: 1440px` shell (:501) -- 340px of dead margin on the
  default tab; `.ov-block { margin: 0 0 16px }` (:37).
- Shell: one full-width panel per tab (:505), logs 38:62 phi split >= 1000px
  (:489-495), mobile stack <= 760px (:507-514).
- Type: 14px/1.45 base (:9); table/crumb text 12-12.5px; captions 10.5-11px;
  outliers at 9.5-10px (`gbar-lab` :407, `sys-tag` :108).

### Rules to tighten (P0, all UI-only)

1. Density floor: nothing below 11px except gantt bar labels; replace
   9.5-10px with 11px. Caption case stays (matches the register's
   letter-spaced small-caps chrome).
2. Contrast: bump `--dim` (B9) -- "more text clearly visible" is 90% this
   one token; keep `--muted` as the secondary voice.
3. Margins: `#grid` padding to `0 16px 20px`; `.ov` max-width to 1320px
   (keeps line length sane on wide monitors without the dead zone);
   `.ov-block` 16px -> 10px. Leave table cell padding at 3px 6px -- it is
   already the right density.
4. Heights: `.sv`/`.kb` fixed `calc(100vh - 120px)` panes become
   `min-height` + `max-height: calc(100dvh - 120px)` so short viewports
   shrink instead of clipping (auto-resizing half of the directive).

### Top-flowing audit (newest-first per view)

| View | Ordering today | Compliant |
| --- | --- | --- |
| Logs reports | crumbs reversed, newest first (app.js:318) | yes |
| Overview crumbs | newest first (overview-view.js:91) | yes |
| Overview blocks | verdict -> items -> crumbs -> dispatch | yes (is-it-OK first, per design-notes convergence #1) |
| Sessions sidebar | live first, then most-recent activity (sessions-view.js:244-249) | yes |
| Research board | kanban by state | yes (state order is the meaning) |
| **Plans table** | feed order = oldest first (plans-view.js:44) | **no** -- fix with B1 |
| KB list | kb/index.json order | acceptable (index order is curated) |

### Auto-resize audit

- Fixed-width traps: `.gantt-inner` min-width 540px with `.gantt-scroll`
  overflow-x (:148-149) -- correct scroll-when-it-must; `.gitem .gname`
  180px (:98), `.sched-label` 96px (:202), gantt label column
  `minmax(190px,260px)` (:214) -- all clamp, none overflow.
- Breakpoints measured: 1000px shell engage, 920/900px session/kb stack,
  760px mobile, 560px system single-col. No horizontal page scroll at any
  probed width except inside the gantt scroll container (by design).
- Risk: `th { position: sticky; top: 0 }` (:127) is a no-op outside
  `#logs-digest` (max-height 40vh, :209) -- harmless, not a defect.

### Mobile posture

Currently: viewport meta set (index.html:5), grids collapse, header hides
`.sub`/`.clab` <= 760px (:507-514), LCD ticker keeps animating (marquee is
pausable on hover only -- useless on touch; motion is display decoration,
acceptable but noisy). Sessions rail scrolls horizontally with
`scroll-snap-type: x proximity` (:315) -- usable on touch. Recommendation:
keep the read-only mobile posture as-is; spend nothing beyond B9 and
`prefers-reduced-motion` on `.sess-*` animations (parity with the ticker's
:446-448). A dedicated mobile layout is a not-build.

## 5. Implementation plan (phased; execution is a later beat)

Effort: XS <1h, S ~1 view-file slice, M ~1 server route + view change.

### P0 -- land first, all UI-only, zero authority change

| Item | Files | Effort | Notes |
| --- | --- | --- | --- |
| B9 contrast token | style.css:5 | XS | one token, every view brightens |
| B2 dispatch link probe | overview-view.js:121 | XS | copy research-view probe pattern |
| B1 plans search/filter/sort | plans-view.js | S | newest-first default |
| B3 refresh coherence + poll pause/backoff | app.js, 5 view files | S | shared helper or per-view guard |
| B13 title badge | app.js renderHeader | XS | |
| Layout tightening (rules 1-4) | style.css, overview-view.js STYLE | S | |

### P1 -- interactivity that needs small server work

| Item | Files | Effort | Server capability |
| --- | --- | --- | --- |
| B4 spawn/tile buttons | sessions-view.js (+ server docstring unchanged) | S | endpoints exist; lands plan step 5 minimally |
| B5 session slicing | dashboard-server.py (new GET, validate + tail-slice sessions.json), sessions-view.js, schedule-view.js | M | yes -- read-only GET |
| B6 SSE push for operator-items/verdict | dashboard-server.py (mtime-watched stream), app.js | M | yes -- replaces 10s poll |
| B7 telemetry stat row | jobs/telemetry-report.py (emit telemetry.json), overview or system-view | M | yes -- feed only |
| B8 mark-read surface | dashboard-server.py (POST wrapping scripts/report-queue --mark-read), app.js Logs | S | yes -- operator-owned ledger action |
| F3 token guard (plan step 6) | dashboard-server.py, views | M | yes -- security, fail closed |

### P2 -- polish after P0/P1 prove out

- B10 jailed plan-doc route + expandable plan rows (dashboard-server.py,
  plans-view.js).
- B11 keyboard roving/focus, B12 density toggle, B14 feedback receipt.
- Sessions keystroke debounce (sessions-view.js:505).

### Governance note

UI mutations must stay within the already-permitted families, all
display/ledger-only per the server docstring (dashboard-server.py:2-10):
operator feedback, operator-item dismissal, advisory backlog prose, the
three display-only system ops, and desktop spawn/tile. Nothing here adds
governance authority: no certificate, queue, plan-status, or kernel-surface
buttons; report-queue --mark-read (B8) advances the operator's own reading
cursor and stays handoffs-logged; --prune is deliberately left CLI-only
because it deletes ledger rows. Spawn/tile remain client-names-a-launcher,
never a command (server rule, :24-34). The POST token guard (F3/plan step 6)
is a security fix, not an authority change, and should not wait on this
beat.

## 6. Verdict

### The 3 changes that would most transform daily use

1. **B1 -- Plans tab search/filter/sort, newest-first.** The operator's
   daily instrument is the 170-row plan ledger; today it is the least
   interactive surface on a dashboard that advertises itself as the
   nervous system. One view file, an afternoon, felt every day.
2. **B5+B6 -- data shaping: slice sessions.json, push operator items.**
   Together they convert the fetch model from "poll whole blobs" to
   "receive what changed" -- the difference between a page that scales
   with the fleet and one that doesn't. B6 alone is what makes the
   dashboard feel alive instead of sampled.
3. **B4 -- spawn/tile buttons in the Sessions sidebar.** Unlocks the
   orphaned plan step 5 with zero server work: the operator finally gets
   the manual-session control the server has validated all along
   (launcher-key-named only). It is the difference between watching the
   system and using it.

### The 3 to explicitly NOT build

1. **No websocket layer.** The data changes on 30m cadences; SSE over
   mtime checks (or even continued polling at sane intervals) covers it.
   A bidirectional socket is infrastructure for zero bidirectional need.
2. **No framework, no virtualization, no drag-layout.** 170 rows render
   in a plain table; the MOUNTS pattern (app.js:620-628) with per-view
   lazy init is doing exactly what React/GridStack would do, minus the
   dependency. The system-view comment ("no GridStack, no drag", :10-13)
   already says this -- keep believing it.
3. **No governance actions in the UI.** No propose/accept/close-run, no
   queue reorder, no pacman -Syu button, no session kill. The write
   surface is deliberately narrow; widening it converts the dashboard
   from a nervous system into a nervous hand on the wheel. Kill/respawn
   decisions stay in agent-watchdog's logged-decision lane (:1-8).

### One-line answer to the operator's question

The dashboard is a read-only mirror with 7 of 10 write routes wired and
zero push; the next interactivity is not more buttons -- it is (a) the three
orphaned operator controls, (b) server-side shaping of the two big feeds,
and (c) push for the attention surface, wrapped in the one-token contrast
fix and newest-first ordering that the layout directive is really asking
for.