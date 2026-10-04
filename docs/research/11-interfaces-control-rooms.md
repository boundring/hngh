---
category: interfaces/control-rooms
persona: The Experience Architect
status: seed
anchored: 2026-10-03
note: automation anchors predate the 2026-10-04 control-room cut (broadsheet/ghost/wire surfaces retired)
---

# Interfaces & Control Rooms — what hngh runs today

hngh's control room is a static-HTML dashboard served fail-closed on :8890 with a fixed identity: **winamp is the only theme** — `THEMES = ['winamp']`, no theme button, first visit must land on it (automation/dashboard/app.js:915-923; glossary at automation/dashboard/console.html:174-178; enforced by the `default-theme-winamp` audit rule in automation/jobs/ui-audit.mjs:62-66). The skin is a documented near-cousin of Winamp base-2.91: "Tokens from PLEDIT.TXT/VISCOLOR.TXT (via Webamp); geometry conventions from packages/webamp/css/base-skin.css. Square, beveled, dense; green LCD on charcoal; playlist stripes visible; no glow, no rounded corners" (automation/dashboard/style.css:518-528, with `border-radius: 0` globally at :529 and hard-bevel chassis panels at :536-574). Wave 1 added playlist-editor schedule rows (uniform 48px rows, LED greens), an LCD marquee ticker, panel shade/roll-up, and a status bar (kernel CHANGELOG.md:1431-1434).

The console carries a deliberate surface boundary: the **kernel gate** state is "deliberately not surfaced here — dashboards never feed a gate" (automation/dashboard/console.html:177). The **broadsheet** (newspaper) lane is under active editorial work — the 2026-10-03 tranches (`docs/records/2026-10-03-newspaper-readability-tranche.md`, `docs/records/2026-10-03-dashboard-deficiency-tranche.md`) record readability and deficiency findings from the newspaper-first direction. The **map** is a vendored three.js (r160) node graph: seed nodes (operator host, kernel core, automation ring, cadence tiers, userspace home, remote origin) plus live fleet.json nodes with online/offline colors, drag-orbit + wheel-zoom, and "any failure falls back to a 2D SVG list" / unknown fields print 'unresolved', never a guess (automation/dashboard/broadsheet-view.js:12-16,1360-1364,1428-1431).

Quality gates are part of the interface: `jobs/ui-audit.mjs` runs axe-core + display-register rules + the **Winamp floor** — "density allowed, illegibility never" — filing per-rule dedup identities into the report ledger and failing closed (automation/jobs/ui-audit.mjs:5-9). The direction doc names the collision deliberately: "Skins as personas, LCD ticker with opinions... Collision with the a11y findings is deliberate: character and compliance in the same pass" (docs/design/presentation-direction.md:43-46). Stage 6 queues the bigger bet — GridStack widget grid, uPlot charts, Winamp-skin-parser themes, procedural/WebGL/music-reactive effects, all behind the display register (docs/project/roadmap.md:31-32).

## Open questions for web research

1. Skeuomorphic skins vs accessibility standards: documented reconciliations (contrast, hit targets) in skin-heavy UIs.
2. Newspaper/broadsheet editorial layouts as data-dashboards — typographic and column-flow practice.
3. 3D node maps with hard 2D fallback: performance budgets and graceful-degradation precedents.
4. Programmatic a11y auditing (axe-core) over static self-served pages in CI — rule design beyond stock axe.
5. Draggable/skinnable window-frame web UIs (winamp-style chrome) — maintained implementations beyond Webamp.

## Candidate external systems to survey

- Webamp (skin token provenance)
- Grafana (theming + a11y posture)
- Homepage / Heimdall (homelab control rooms)
- Umbrel OS (dashboard conventions)
- GridStack / uPlot (queued stage-6 dependencies)
