# rp-logs-crumbs: app.js logs-reports crumb facet/filter rendering

Scope: `automation/dashboard/app.js` logs tab (Reports|Digest sub-toggle) only.
Sibling artifact `rp-overview.md` covers overview-view.js.

## State and constants

- `facet = { event: '', job: '', text: '' }` — module-level facet state, display only (app.js:470). Comment at app.js:465-469: facets filter only fields the feed really carries (event, job, detail text); no severity chips because the feed has no severity field yet.
- `curCrumbs = [], lastOpCount = 0, lastDigestLines = 0` — crumb rows cache plus summary counters (app.js:471).
- `curCrumbs` is filled from the fetch payload in `renderLogs`: `curCrumbs = (d && d.breadcrumbs) || []` (app.js:616), i.e. data.json `breadcrumbs` array; empty-safe.

## Filtering and row rendering

- `facetActive()` — true when any facet set (app.js:472).
- `crumbClass(ev)` — heuristic severity: `/CRITICAL|alert|failure/i` -> `alert`, `/NOTABLE|steer|done/i` -> `notable`, else `''` (app.js:473-476). Display approximation only.
- `visibleRows()` — `curCrumbs.slice().reverse()` (newest first) filtered by exact event match (`(c.event || '(none)') !== facet.event`), exact job match, and lowercase substring on `detail` (app.js:477-485). Missing fields normalize to `'(none)'` so "(none)" chips/jobs are filterable.
- `crumbRow(c)` — one `<div class="crumb {class}">` with `ageChip(c.ts)`, `.cts` timestamp, `.cjob`, `.cevent`, `.cdetail` (title attribute carries full detail) (app.js:486-495). All text through `esc()`.
- `renderCrumbRows()` — groups visible rows by job into `<details class="crumb-group">`; group summary shows job, row count, and worst severity (alert > notable); alert groups render `open` (app.js:499-526). Group order = first appearance in newest-first order.
- Summary line `logsSum()` — "N operator items · X of Y entries (filtered) (Z attention in view) · digest L lines" (app.js:527-535).

## Facet controls (cf-chip)

- `renderReports()` (app.js:572-603) is the Reports-pane builder:
  - Empty state: `if (!curCrumbs.length) { body.innerHTML = '<div class="ok-note">no reports</div>'; return; }` (app.js:574).
  - Builds event counts `evCount` and job counts `jobCount`, `(none)` for missing fields (app.js:576-580).
  - Event chips: `<button class="cf-chip" data-fevent="EV" aria-pressed title="filter reports by event">EV count</button>`, sorted by count descending (app.js:581-588); chip "on" state reflected in `aria-pressed` at render.
  - Job select: `<select class="cf-input" id="logs-fjob">` with "all jobs" default plus one `<option>` per job with counts (app.js:589-597, 596).
  - Text input: `<input id="logs-ftext" placeholder="filter detail…" value="esc(facet.text)">` (app.js:598-599) — current text facet is re-hydrated into the rebuilt input.
  - Re-renders facet bar + `#logs-rows`, then `bindFacets()` and `renderCrumbRows()` (app.js:601-602).
- `bindFacets()` (app.js:536-553): chip click toggles `facet.event` (same value clears it), job select change sets `facet.job`, text input `input` event sets `facet.text` with rows-only re-render so typing focus is kept (comment app.js:551).
- `applyFacets()` (app.js:554-561): syncs every `#logs-reports .cf-chip` `aria-pressed` from `facet.event`, then `renderCrumbRows()` + `logsSum()`.
- Styling: `.cf-chip` / `.cf-chip[aria-pressed="true"]` accent state in `automation/dashboard/style.css:64-66`; `.crumb-facets` bar style.css around line 62; `.crumb`, `.cjob`, `.cevent`, `.cdetail` in the "logs: operator items + reports rows" block (style.css, logs section ~lines 45-75).

## Digest vs Reports toggle

- `setLogView(v)` (app.js:562-571): `v === 'digest'` hides `#logs-reports` / shows `#logs-digest`, toggles `.on` class and `aria-selected` on `#lt-reports` / `#lt-digest`, and persists to `sessionStorage['hngh-logs-view']` inside try/catch for private mode (app.js:570).
- Click wiring: `#lt-reports` -> `setLogView('reports')`, `#lt-digest` -> `setLogView('digest')` (app.js:798-799).
- Restore on boot: read `sessionStorage['hngh-logs-view']`, default `reports` (app.js:800-802); a `#hash` media handler can also set the view (app.js:805); tab-change handler reapplies sub-view: `if (h && h.name === 'logs' && h.sub) setLogView(h.sub === 'digest' ? 'digest' : 'reports')` (app.js:936).
- Markup: buttons `#lt-reports` (default `on`) and `#lt-digest`, panes `#logs-reports` (visible) and `#logs-digest hidden` — `automation/dashboard/index.html:102-108`.
- `renderDigest(d)` (app.js:604-610): renders `d.digest` through `miniMd()` into `.digest.md-body`; sets `lastDigestLines`; empty/missing digest -> `<div class="ok-note">no digest content</div>` and `lastDigestLines = 0` (app.js:607). Digest pane is max-height 40vh scrollable (style.css `#logs-digest`).

## Empty-state and missing-note paths (verified)

1. No crumbs at all: Reports pane shows `ok-note "no reports"` (app.js:574); `renderCrumbRows` would also show `ok-note "no reports"` (app.js:504, second branch).
2. Crumbs exist but facets filter everything: `renderCrumbRows` shows `ok-note "no entries match the active filters"` (app.js:504, first branch). `logsSum()` still reports "0 of Y entries (filtered)".
3. Digest missing/empty: `ok-note "no digest content"` (app.js:607).
4. Both data sources unreachable: fetch chain catch sets `missing-note` "both data.json and readout.json unreachable" (app.js:694); on `res.error` both panes get `missing-note` with the full reader-only explanation message and `headerNoSignal(msg)` runs (app.js:697-703). Note this path bypasses `renderLogs`, so `curCrumbs` stays stale from a prior successful render (first-boot default is `[]`).
5. data.json unreachable but readout.json works: spine fallback, `stale-note` in footer meta (app.js:689-691) — `d` is null so `curCrumbs` becomes `[]` via app.js:616, i.e. Reports pane shows "no reports".
6. Operator items (the "For the operator" block above reports, app.js:611-615 via `operatorItemsHtml` app.js:176-190): feed-unavailable falls back to legacy digest bullets; no items -> `ok-note "nothing flagged for the operator"` (app.js:189).

## Observations (no edits made)

- Event chips are re-created on every `renderReports()` (each fetch), while `applyFacets` only updates `aria-pressed` in place — consistent, since chips are rebuilt with current `facet.event`.
- Facet state persists across re-fetches (module-level `facet`), including the text filter re-hydrated into the rebuilt input (app.js:599).
- `esc()` wrapping throughout; chip `data-fevent` and option values escaped, so events containing quotes degrade safely.
