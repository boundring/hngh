# Dashboard design notes — making system/application info readable at a glance

Research pass on how real, lauded dashboards that display system + application
state make dense data easy to read at a glance. Baseline this improves:
`hngh-automation/dashboard/` (static webapp, live :8890) and its six open UX
issues — visibility-by-default, window-fit widgets, meaningful-at-a-glance
stats, legible schedule, digest-in-place, single toggle. No code here; notes +
a ranked borrow-list for the static webapp.

## Surveyed projects and the pattern each is good at

### Grafana — default-visibility, one-metric-per-panel, stat panels
- Every panel is one idea; a **stat panel** shows a single large number with an
  optional sparkline, so the eye lands on the headline figure before any axes
  or labels ([Stat viz](https://play.grafana.org/d/Zb3f4veGk/stats)).
- Best-practice guidance pushes **information hierarchy**: put the metric that
  answers "is this OK?" first, use the space for the number, not the frame
  ([best practices](https://grafana.com/docs/grafana/latest/visualizations/dashboards/build-dashboards/best-practices/)).
- Dashboards default to **all panels visible**; rows/panels collapse only on
  demand, never as the resting state.

### Datadog / Prometheus — the **"is it OK?"** summary line drives the layout
- Screenboards lead with service-health tiles: green/amber/red state encoded in
  **color before text**, so a red tile is legible from across the room without
  reading a number. Text confirms the state; color announces it.
- Detail is always one click away behind the tile — the summary is the default,
  the query browser is the drill-down.

### netdata — per-second auto-refresh, everything visible, zero click-to-reveal
- Refreshes charts **continuously at per-second granularity**; width drives how
  much history is shown, so the widget always fits its window
  ([auto-refresh tied to width](https://sources.debian.org/data/main/n/netdata/1.12.0-1%2Bdeb10u1/web/gui/dashboard.html)).
- Brand goal is literally *"clear insights at a glance, no complexity"* — a
  whole machine is on one scrolling page, none of it hidden behind a fold
  ([netdata positioning](https://www.netdata.cloud/)).
- What it sacrifices: everything is visible so nothing is curated; it works
  because the per-metric tiles are tiny and each self-describes.

### Temporal / Airflow DAG UIs — schedule/queue as *time*, not numbers
- A **workflow/schedule is drawn as a timeline**: a bar/dot on an axis with an
  explicit "running now" cursor. The eye reads *when things happen* and *where
  we are*, which a list of counts cannot express.
- Queued vs running is encoded by **position on the axis + marker color**, not
  by a status word.

### GitHub Actions / Azure DevOps pipelines — grouped digest, one toggle
- The whole run is a **vertical digest** — steps collapse into rows whose status
  color is the only thing you scan; a single chevron/toggle expands in place to
  see logs. No modal, no page navigation.
- Headline is the **overall run badge** (pass/fail) with per-step color below it:
  one glance answers "did it work", a click answers "why".

### Terminal density conventions — btop/htop, gnuplot
- htop/btop show **dense, always-on, window-fitted panels**: horizontal
  bar meters (`█████░`), a per-core grid that fits any terminal, and *total* at a
  glance with per-item expanded only on request. Nothing is hidden by default;
  every meter has a fixed, small footprint.
- gnuplot proves a static artifact can convey a schedule: a **timeline/gantt
  rendered to a plain image** tells the story without any interaction at all —
  the whole "what's due when" fits in one viewport once it's drawn as bars.

### Jupyter / GNOME system monitor — minimum viable at-a-glance
- GNOME Monitor is the archetype of "number in a corner, color bar beside it":
  a table where the *state is pre-digested* by the tool (load, %, count) rather
  than left as raw figures for the human to interpret.

## What these converge on

1. **State before data.** Color/position communicates *is it OK?* in under a
   second; the number/text confirms it. (Grafana stat, Datadog tiles,
   GitHub badge, GNOME).
2. **One idea per tile.** A dashboard is a mosaic of single-fact tiles, each
   self-describing and tiny, so the whole fits the window — not one tall grid
   of full detail. (Grafana, netdata, btop).
3. **Visible by default, collapse on demand.** Hidden panels are the anti-pattern;
   the resting state shows every tile, density handled by *tile size* not by
   *hiding* (netdata, Grafana, btop).
4. **Dense-but-scrollable areas use colored digest rows + in-place expand.**
   When a region must be long, each row carries a status color and collapses to
   one line; detail opens *in place*, never a separate page/modal (GitHub
   Actions, Azure pipelines).
5. **Schedule/queue is drawn as a timeline**, not counted. The "running now"
   cursor on a time axis is the legible form (Temporal, gnuplot, gantt).
6. **Auto-refresh tied to viewport** keeps a live surface honest without
   interaction (netdata).

## Borrow-list for the current static webapp (ranked by effort/impact)

1. **Reverse the collapse default — visibility-by-default.** Only Gantt is open
   (`data-open="1"`); the other eight panels rest closed. Flip the resting state
   so Overview/Timeline/Queue/Lanes/Roster all show (density via tile size, not
   hiding — §3). *Cheap (one line per panel), highest visibility win, directly
   hits UX issue #1.*
2. **Stat-tile overview.** Replace the overview paragraph with Grafana-style
   stat tiles — one big number each (open lanes, queued items, running agents,
   oldest wait) with color = health. *Tiny renderer change, no new data; issue
   #3.*
3. **Status color first.** Give every row (queue, lanes, roster, timeline) a
   leading colored state glyph that is legible before reading the text —
   Datadog/GitHub color-before-text. *CSS + one map from state→color; issue #3/#4.*
4. **Fit the gantt to the window.** netdata's width-tied rendering: auto-fit the
   gantt day-axis to measured panel width instead of the fixed `fitPx: 780`, so
   the schedule read is whole when open. *Already have `fit`/`zoom`; make fit the
   default on resize. Issue #2.*
5. **Digest-in-place.** Make Reports/Digest panels collapse each long entry to a
   colored one-liner with in-place expand (GitHub Actions pattern) instead of
   opening full text. *One renderer tweak; issue #5.*
6. **Single toggle, applied everywhere.** Unify the collapsible panels onto one
   expand/collapse behavior (already `data-open` + `bindPanels`) so dense areas
   use the same affordance as the tiles. *Issue #6; small.*
7. **(Defer) running-now cursor on timeline.** Draw the "current time" marker
   on the timeline axis (Temporal) — the readout already carries timestamps
   (`timeline`), so this is a front-end-only line. *Nice, but needs the gantt fit
   first.*

Ranked by effort/impact: 1→2→3→4→5→6 are all small and front-end-only (no new
backend), 7 deferred until 4 lands. Nothing here requires a new data source or
a server change — the readout spine already carries everything.

## Sources

- Grafana Stat viz: https://play.grafana.org/d/Zb3f4veGk/stats
- Grafana best practices: https://grafana.com/docs/grafana/latest/visualizations/dashboards/build-dashboards/best-practices/
- netdata width-tied auto-refresh: https://sources.debian.org/data/main/n/netdata/1.12.0-1%2Bdeb10u1/web/gui/dashboard.html
- netdata "at a glance" positioning: https://www.netdata.cloud/
- Baseline webapp: `hngh-automation/dashboard/` (`index.html`, `app.js`, `readout.json`)
- Prior UI loop baseline: `docs/research/2026-08-26-evolutionary-ui-loop.md`
