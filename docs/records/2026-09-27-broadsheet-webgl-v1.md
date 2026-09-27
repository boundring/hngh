# Broadsheet WebGL front page v1 — 2026-09-27

Operator directive: replace the tiled dashboard with a single continuously
vertically-scrolling WebGL newspaper "broadsheet", built standalone first.
This record documents the v1 build: what renders, where dependencies come
from, what falls back to what, and which behaviors remain cutover-dependent.

## Scope and file boundary

Built standalone; nothing existing was modified. Owned files:

- `automation/dashboard/broadsheet.html` — mount point: paper canvas, error
  banner, masthead, toolbar, map block, stream, sentinel.
- `automation/dashboard/broadsheet-view.js` — all behavior, single IIFE,
  classic script (no bundler).
- `automation/dashboard/broadsheet.css` — paper palette, column layout,
  choice buttons, divider, fallback paper.
- `automation/dashboard/broadsheet.sample.json` — synthetic 13-article
  fixture (clearly labelled as such in-page) used until the composer feed
  `newspaper.json` exists; loaded via `?feed=` query override.
- `automation/dashboard/vendor/three.module.min.js` — vendored three.js.
- `automation/dashboard/fonts/AveriaLibre-*.woff2` — four vendored faces.
- `automation/tests/test-broadsheet-view.py` — 17 static contract tests.

Explicitly untouched: `index.html`, `console.html`, `newspaper-view.js`,
`style.css`, `dashboard-server.py`, `Makefile`, `CHANGELOG.md`.

## Paper renderer

Raw WebGL2 fragment shader on a fixed fullscreen canvas behind the content;
the DOM scrolls above it. One fullscreen-triangle vertex shader; the fragment
shader composes the sheet procedurally: anisotropic fiber noise (high
frequency across the web, low along it), sparse round darker flecks from a
hash of coarse cells, three rotated soft dapple-shadow layers (per-layer
amplitude 0.055/0.045/0.035, combined under the 0.08 opacity ceiling) drifting
on a ~50-second breath, a slight emboss, and a vignette. The base tone is warm
`#f4f0e6`; scroll position drives a warm → neutral → cool tint lerp. Rendering
is capped at ~30 fps, pauses when the tab is hidden, and the DPR is capped at
1.6. No texture assets — everything is procedural.

## Megastructure map

three.js (vendored ES module, r160) renders a ~33vh orbitable graph under the
masthead: eight static seed nodes (operator host, kernel core, automation
ring, cadence hour/subhour/calendar, userspace home, remote origin) in three
layers, plus a live ring of `fleet.json` nodes at ground level — green
(0x4a6b3a) when online, red (0x8a4a3a) when offline, and the literal `?` node
renders with the label "unresolved". Edges are line segments; labels are
canvas sprites; the whole mesh rotates slowly (0.0012 rad/frame). Pointer
drag orbits (phi clamped 0.5–2.6), wheel zooms (throttled 120 ms, distance
4–22). Build is guarded so the init and refresh paths cannot double-build.

## Feed and infinite scroll

The stream is CSS multi-column (`column-count` 1–5, default 3, persisted in
localStorage under `broadsheet-cols`, changed by toolbar buttons or `[` `]`).
Articles render kicker + queue chip, headline (click expands to
`column-span: all`), italic deck, lede, and a folded body; span values from
the feed are respected, span-3 renders full-width expanded. Choice buttons
are moss green with the outcome shown in italics before any click; a click
POSTs via `postJson` with the `X-Hngh-Token` header from the token meta, and
endpoints are whitelist-gated to `/operator-item/handle` and
`/operator-item/dismiss`.

The sequence is score-sorted current articles, then archived editions
(oldest last), then a `FRESH EDITION` divider at the wrap, repeating forever.
Lazy rendering appends while the sentinel sits inside a 900 px look-ahead
window; the DOM caps at ~400 nodes and trims from the top with a note linking
back to the front page.

Live-verified 2026-09-27 against `?feed=broadsheet.sample.json`: wrap divider
renders at each loop (65 articles / 3 dividers observed in one session), the
DOM grows and trims, columns persist across reload, and no console errors.

## Lazy-render guard note (observed failure, root cause)

An IntersectionObserver alone cannot drive this render: the sentinel can
remain intersecting across appends — a state that never transitions never
re-fires the callback. Observed live twice: (1) the observer fired once while
the stream was still empty and the feed stalled at 6 articles; (2) with the
sentinel landing at exactly the viewport edge, Chromium requires strict
containment for zero-area targets and no transition fired at all. The fix is
a bounded `fillToSentinel()` loop (12 appends per call) funneled from the
observer, a passive scroll listener, and the rebuild path.

## Vendored dependencies

- `vendor/three.module.min.js` — three.js r160, fetched from jsDelivr
  (670,681 bytes), served locally; never fetched at render time.
- `fonts/AveriaLibre-{Regular,Bold,Italic,BoldItalic}.woff2` — Averia Libre
  (SIL OFL) TTFs from the google/fonts repository, converted with
  `woff2_compress` (39–44 KB each), `font-display: swap`.

## Fallbacks

- No WebGL2, failed shader compile, or a lost context (after restore is
  declined) drops the canvas and adds `body.paper-fallback`: a flat CSS paper
  tone. Context restore re-runs the init path.
- No WebGL or failed three.js import replaces the map with a static list of
  nodes and status dots.
- Any feed failure renders a fail-closed `#papererr` banner; the page never
  goes blank.

## Deviations and cutover-dependent behavior

- Token injection: `dashboard-server.py` injects the real `hngh-token` meta
  only into `/`, `/index.html`, and `/console.html`. Until the cutover adds
  `broadsheet.html` to that list, the page ships an empty placeholder meta,
  choice POSTs fail closed (403), and the operator sees the error line. This
  is a server-side one-line cutover, not a broadsheet defect.
- Feed source: `newspaper.json` does not exist yet (the composer is building
  in parallel). Development and verification used the clearly-synthetic
  fixture via `?feed=broadsheet.sample.json`; the page shows a "SYNTHETIC
  FIXTURE — practice edition, not real reporting" badge whenever the feed is
  not the default.
- Refresh semantics: the 30 s poll chain (backoff to 120 s, paused hidden)
  updates the masthead and map; the already-rendered stream is not rebuilt,
  by design — new editions arrive on manual refresh or reload.
- Masthead dates come from the feed stamp (`generated`), never client time.

## Deferred (not built)

- Page-curl physics or per-article graphics beyond the headline/queue
  treatment.
- Cutover and archival of `index.html`/`console.html` — orchestrator-
  directed, out of scope for v1.

## Cutover (same day, orchestrator-directed)

The broadsheet became THE dashboard front page:

- Token injection: `dashboard-server.py` `_serve_index` now serves
  `/broadsheet.html` alongside `/`, `/index.html`, `/console.html` (one
  code path — the route tuple plus a basename mapping), so the real
  `hngh-token` meta reaches the broadsheet and choice POSTs authenticate.
  Verified live: 32-char token injected; a probe POST to
  `/operator-item/handle` with the page token returned 201, not 403.
- `index.html` is now the broadsheet mount (same markup/asset paths as
  `broadsheet.html`, which remains as the standalone original), with a
  "nerve center" link to `console.html` in the toolbar; `console.html`
  already linked `index.html` as the front. Specialty pages
  (story/history/routes/gantt) stay on disk, reachable from the console.
- Default feed: the page already defaulted to `newspaper.json`; the
  composer (`scripts/newspaper-compose.py`, cadence subhour beat) produced
  the first live edition on 2026-09-27: 397 articles, 15 categories,
  40 operator-decision cards, 7 archived editions, open-meteo weather.
  The SYNTHETIC FIXTURE badge now appears only on explicit `?feed=`
  overrides. `newspaper.json` itself stays untracked (dashboard machine
  data, quarantined by `automation/.gitignore` like the other feeds).
- Link-contract tests repointed: `test-newspaper-view.py` now pins the
  broadsheet front wiring/a11y and keeps index→console / console→index;
  `test-story-view.py` pins story reachable from the console instead of
  the front (history/routes tests never pinned index).
