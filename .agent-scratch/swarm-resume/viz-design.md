# Megastructure visualization design proposal (viz-design)

Date: 2026-09-15. Status: DESIGN PROPOSAL (read-only synthesis). This artifact
merges the sibling explore artifacts in this directory; every claim that rests
on a sibling is marked `[viz-*]` or `[hist-*]`. No re-investigation performed.

Display register: everything below renders in the hngh dashboard (display
layer) or in jcode TUI surfaces; nothing here is ever a governance input
(checklist in section 5).

## 1. Staged ladder

The megastructure viz is a ladder of surfaces that visualize the hngh
automation estate (kernel + automation + agent sessions) at increasing
historical depth and richness. Each rung ships independently and leaves the
previous rung untouched.

### Rung 0 (exists): current-state graph
`/graph.json` (graph-data.py) -> graph-view.js radial snapshot, 13 kinds,
4 states, recency pre-baked into states, no time axis. [viz-graph-payload]

### Rung 1 -- FIRST SHIPPABLE INCREMENT: history/1 feed + History spine view (View A)
Produce the pinned `{"schema":"history/1","entries":[...]}` merged feed
(gitlog + reports + records + journal), serve `/history.json`, render the
vertical reverse-chron source-tagged stream with filter chips, server-side
window selector (24h/3d/7d), per-source caps and fail-closed banners.
Estimated M (producer) + S (serve) + M (view), ~2-3 jcode-sessions total for
this rung plus View B. [viz-history-work-parent sections 1,3,4;
hist-windows-schema pinned envelope]

Why this first: it is the only rung whose backend does not exist (the
envelope schema is already pinned and gated in viz_schema.py [hist-windows-
schema]), it unlocks every later time-axis view, and its producer lives in
the automation/jobs free-commit lane (no kernel surface). View B (upcoming-
work board) is optional same-rung follow-up, mostly wiring existing feeds
[vis-history-work-parent section 3].

### Rung 2: time-axis density + upcoming-work board
View C day-density past-marks on the existing gantt engine
(`window.GanttEngine.mount`, the only time-axis renderer today) [hist-
renders-b via viz-history-work-parent section 2]; View B three-zone board
(queue / next runs / plan steps) from plans.json + schedule.json, both feeds
already served. [viz-history-work-parent section 1]

### Rung 3: session-lane visualization over the delegate transport
Structured render envelopes from delegated jcode sessions: turn on
`JCODE_WORKER_RENDER` and add the missing downstream consumer
(`parseRenderSection` currently has zero callers [viz-transport-worker key
finding]), then visualize envelope streams (tool call/error + usage
timelines) per delegated session in the dashboard, cross-linked from
sessions-view rows. [viz-transport-worker]

### Rung 4: in-TUI megastructure views (jcode side)
Side-panel pages (or a new render-target) carrying the same
history/upcoming payloads, using the serializable primitives of section 2.
This rung depends on jcode, not hngh, and is the least certain; it is
explicitly last. [viz-inventory-tui-formats, viz-sidepanel]

## 2. Shared primitives

These primitives are shared across rungs; each is grounded in a sibling
artifact.

- **Envelope/version convention** `<family>/<int-major>` on the `"schema"`
  string, stdlib-only fail-closed validator in `automation/jobs/viz_schema.py`
  as the single authority; additive enum/optional-key extension without bump
  (WARN lane), breaking top-level/required/type change bumps major. Every
  new family (`history/1` exists; a future `delegate/1` for rung 3) follows
  this. [viz-envelope-version sections 1,3,5]
- **Payload discipline**: plain JSON types only (survive
  `json.loads(json.dumps(...))`), unknown-key fail closed at top level,
  WARN-lane nested extras, consumers fall back to neutral rendering on
  unknown enums. [viz-envelope-version section 3; viz-docs-serialization
  lesson]
- **Node/state vocabulary**: reuse the graph's 13-kind / 4-state
  (healthy/stale/alerting/neutral) enums and id-prefix namespaces wherever a
  new view shows hngh entities; new kinds extend additively. [viz-graph-
  payload]
- **Data feeds**: `/graph.json`, `plans.json`, `schedule.json`,
  `sessions.json` + `/session/<id>` + `/telemetry.json` already exist; the
  new `/history.json` (rung 1) and a future delegate-envelope feed (rung 3)
  join them. Producers import seam constants; server passthrough with short
  cache and last-good fail-soft, per graph_feed() pattern. [viz-graph-
  payload; viz-history-payload; viz-history-work-parent section 1]
- **Frontend conventions**: fetchJson/fetchText abort helpers, `esc()`,
  owned `<style>` tag, `window.HnghPoll` refresh, dim placeholders,
  headless pure-function test seams, generalized todayRows windowing,
  GanttEngine for any time axis. [viz-history-work-parent section 2]
- **jcode-side serialization primitives** (rung 4 only): render-core
  `Document`/`Block`/`StyleRole` serde model (the JSON-able semantic form of
  the markdown subset), `SidePanelSnapshot` + markdown-file persistence +
  `side_panel_state` wire event, `RenderedImage` base64 passthrough. Mermaid
  has no dedicated carrier (source lives inside markdown text); if diagrams
  are ever needed, carry source in markdown, not a new protocol type.
  [viz-inventory-tui-formats; viz-sidepanel; viz-docs-serialization; viz-
  render]

## 3. Feed/producer dependencies

- **history/1 producer (rung 1 prerequisite, hard dep)**: not yet produced;
  M-effort job merging gitlog + reports + records + journal with prefix-
  tagged ids, Z-normalized ts, newest-first, dedup fail-closed, validated
  via the viz_schema CLI, atomic publish. All gotchas pinned in
  hist-windows-schema (dedup keys, ts normalization, missing sidecars,
  prune-archive skip). Prefer a fresh `automation/jobs/` job over extending
  `scripts/generate-publication` (repo-root scripts/ is kernel surface).
  [viz-history-work-parent sections 1,4; hist-windows-schema]
- **Serve seam**: `/history.json` in dashboard-server.py, trivial
  passthrough + short cache; also wire `validate_payload` rc-2 ->
  last-good for `/graph.json` (open gap: graph-data.py `build()` does not
  yet stamp `"schema":"graph/1"`). [viz-envelope-version section 6]
- **Existing feeds (rung 2)**: plans.json and schedule.json are complete;
  only render wiring remains. [viz-history-work-parent section 1]
- **Delegate envelopes (rung 3)**: `JCODE_WORKER_RENDER=markers|fd3|both`
  already emits structured v1 envelopes losslessly on fd3 and via stdout
  markers without changing the stdout contract; the missing piece is a
  consumer. Known envelope losses to document in the feed spec: tool
  inputs/outputs not carried (name+error only), unclosed fences dropped,
  classify_cause forced to "unknown" when markers reach the log tail.
  [viz-transport-worker hop table]

## 4. Dependencies on ambient/delegate work

- Rung 3 depends directly on the delegate transport lane: the
  worker.mjs/JcodeClient shim, launch-jcode.sh fd3 side channel, and
  render-blocks.mjs envelopes. It requires no change to the shim; only the
  absent downstream parser + a feed that persists envelopes (e.g. under
  `~/.hngh/dispatch/` per the userspace-home contract) and serves them.
  [viz-transport-worker]
- Rung 3 also depends on sessions-feed rows correctly attributing delegated
  jcode sessions (source `automation`/`bridge` rows) so envelope streams can
  be joined to the roster by session/run id. [viz-history-payload]
- Rung 4 (in-TUI) depends on jcode-side-panel and render-core work owning
  the serializable primitives; hngh-side work should not duplicate them.
  Rungs 0-2 have no jcode dependency.
- Nothing here starts daemons or background processes; feeds are produced by
  existing cadence jobs plus one new 1m/5m-tier producer job, consistent
  with the kernel boundary (no daemon start, no kernel src/ edits).

## 5. Presentation-boundary checklist (adversarial gate)

Against the display register + presentation-boundary law (factual renderer
only, never governance input):

- [ ] Every new surface (history stream, work board, delegate timelines)
      reads feeds read-only and renders facts; no surface writes plans,
      queue, certificates, gates, or kernel state. [viz-history-payload
      guarantee: display layer only, never governance input]
- [ ] Producers are append/derive-only over existing records (git log,
      reports.md mirror, docs/records, docs/journal, delegate envelopes);
      a broken producer leaves the prior feed untouched (atomic publish,
      fail-soft last-good on serve). [viz-history-payload; viz-envelope-
      version]
- [ ] All payloads validate fail-closed at the seam (exit 2 on ERROR);
      unknown envelope keys never silently render. [viz-envelope-version
      section 3]
- [ ] Credentials redacted at feed level, mirroring
      `verify-candidate.py CREDENTIAL_PATTERN`; delegate envelopes never
      carry prompts (worker.mjs:125) and must be redaction-checked before
      first persistence. [viz-history-payload; viz-transport-worker]
- [ ] Rendering conventions inherited (esc(), caps + "(N of M shown)",
      fail-closed banner ids, dim placeholders) so missing data reads as
      absence, not as fabricated content. [viz-history-work-parent
      section 2]
- [ ] No styling/colors enter data: states are enum strings, colors are
      consumer-side constants (graph-view.js COLORS pattern); on the jcode
      side, role-level StyleRole/FillRole only, never ANSI in payloads.
      [viz-graph-payload; viz-inventory-tui-formats section 3]
- [ ] No kernel/gate/certificate state is represented as actionable
      control: drill-downs link to evidence (`/hngh-docs/` jailed route,
      sidecar paths, commit hashes) and never offer mutation affordances.
      [viz-history-work-parent View A; viz-sidepanel]
- [ ] Patrol/alert states shown are derived read-only lookbacks (24h FAIL
      scan, staleness tiers), identical in kind to rung 0; nothing feeds
      back into patrol or cadence decisions. [viz-graph-payload]

## Sibling artifact index

viz-render, viz-docs-serialization, viz-sidepanel, viz-inventory-tui-formats
(jcode TUI formats), viz-transport-worker (delegate lane), viz-envelope-
version (versioning), viz-graph-payload, viz-history-payload (feeds),
viz-history-work-parent (views/effort), plus hist-windows-schema and
hist-renders-b as cited by the parent.
