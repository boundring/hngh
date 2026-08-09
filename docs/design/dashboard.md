# Mission-Control Dashboard + seat windows (card 102) — design v2

**Status**: design v2 (Sanakan 2026-08-09 10:42, owner-directed
architecture). Supersedes v1 (committed 9b81b9e). This is the
integration target for all tandem sessions: launch-time dashboard,
per-seat ride-along processes, tmux interfacing, MCP connectivity.

## 1. Purpose (unchanged from v1, restated)

One surface for the owner to watch, control, and arrange every agent
session. Owner's core preference: watch agents work so mistakes and
mix-ups get caught early; Hngh automates the watching (halt/stall/drift
detection, steering, verification) so the OWNER's watcher role becomes a
background service.

## 2. Architecture (owner-directed, 2026-08-09 10:40)

### 2.1 Startup dashboard window (the pair)
- **At Hngh login/startup**: one terminal window — a tmux session with
  TWO panes:
  - pane A: **Hermes session using system config** (`~/.hermes/config.yaml`,
    the paired session — the owner's always-on attendant).
  - pane B: **dashboard TUI, llmtrim-style** — layout, session stats,
    activity, controls.
- The dashboard pane is a **process that interfaces via tmux** with the
  Hermes session in its own window (send-keys, /steer, input piping).
- **Stats**: the dashboard shows detailed state on every active agent
  session — including the paired one. Same seat-truth rules as v1:
  ACTUAL model (verified, never footer alone), phase, last activity,
  context %, lane state, lifespan.

### 2.2 Each spawned agent gets its own window
- One terminal window per agent, tmux-based:
  - pane 1: **Hermes session** (or Opencode soon) — the agent itself.
  - pane 2: **ride-along panel** — an active process that is the LOG for
    the agent session, linked to it for input handling: prompts,
    steering, TUI controls. The human OR Hngh (dashboard/background
    services) can drive the agent through this panel.
- The ride-along process connects the agent window back to Hngh (see 2.4).

### 2.3 Orchestration layer (Hngh processes behind the dashboard)
- Dashboard links to Hngh processes that TRACK and MANAGE agent
  activity: follow each seat's work, automate the guidance/correction
  actions the owner normally takes — individually or as groups,
  coordinating and orchestrating.
- This is lane-watch generalized: from idle/halt nudging to full
  orchestration (assignment, steering, verification, review gates,
  wind-down).

### 2.4 Connectivity
- **tmux** = the pane-level interface (input piping, /steer, capture).
- **MCP** = agents connect back to Hngh: each window's tmux instance +
  ride-along panel + log + process can serve as the agent's MCP client
  back into Hngh (e.g., hngh-coord's MCP face — the thread Apollo/Killy
  closed this morning with the wire-proven MCP/ACP fixes).
- "Connect each agent window and the dashboard and its agent in any
  number of ways" — wiring is per-use; the DCSS-style rule is: tmux for
  UI-level control, MCP for tool/message-level control, file lane for
  durable coordination.

## 3. Components (decision-complete phases — revised from v1)

### P0 — inventory + registry (done in v1 service-map)
`docs/design/service-map.md` (Sanakan 2026-08-09): seats, systemd user
units, coordination substrate. Registry: `~/.hngh-night/seat-names.md`.

### P1 — dashboard v1: the startup pair + seat windows
- `hngh dash` command: opens the startup window (Hermes + llmtrim-style
  TUI pane), reads seat config, opens per-seat windows.
- Dashboard TUI (llmtrim-style): panes/columns per seat with
  model-truth, phase, last activity, context %, lane state, controls.
- Seat window launcher: `seat-up` (dedicated tmux socket `tmux -L
  <name>`, setsid — seat survives spawner shell death; the 10:22 crash
  lesson), + a ride-along log/interface pane per window.
- Halt/stall detection + nudging (lane-watch generalization): the
  owner's watcher role, procedural-first.
- tmux interfacing: `/steer` via the seat's own socket, care layer for
  stranded input (send → verify → clear/resubmit).

### P2 — per-role model config + FALLBACK PREVENTION (owner-emphasized)
Hermes profiles (`hermes -p <role>`), validated model ids, verified
negotiated model post-spawn (the luna/typo-squat lesson: never trust the
footer; picker is the owner's canonical switch, `-m` can silently
fall back — bad spec → flash).

Owner emphasis (10:44): "agents that spawn off the dashboard, we should
be able to fine-grain-control the configuration applied for them. We
should be able to prevent unintended fallback model activation."

Concrete requirements:
- Per-seat roll config: which provider, which model id, which fallback
  chain (if any) is ALLOWED. Default for spawned seats: NO silent
  fallback — if the pinned model+provider fails, the seat either
  (a) stops and reports the failure, or (b) falls back ONLY to an
  explicitly listed chain member — never to a chain default by accident.
- The 2026-08-09 failures to prevent: (1) `-m gpt-5.6-luna-max` typo id
  resolved to flash via chain default; (2) `-m gpt-5.6-luna` valid-id
  still rendered flash in footer — chain slid before openai served it.
  Both are "unintended fallback activation." Guard = config-level pin
  (fallback_providers empty/restricted, or per-seat override) plus
  post-spawn verification flagging ANY mismatch between requested and
  negotiated model.
- Prompt-lint (card 103) validates the model id in the brief; the
  dashboard validates the id at spawn AND the negotiated model after
  spawn (probe /cmdline, never footer-only).
- UI: requested vs negotiated shown side-by-side; any difference is an
  ERROR-state banner, never a quiet footer.

Authoritative mechanism (hermes docs, hermes-agent.nousresearch.com/docs/
user-guide/features/fallback-providers, read 2026-08-09):
- `fallback_providers:` (top-level list in config.yaml) is tried in
  ORDER when the primary fails with RATE-LIMIT / OVERLOAD / AUTH /
  CONNECTION errors mid-session. Each entry needs BOTH provider and
  model; entries missing either are ignored. `hermes fallback {list,
  add, remove, clear}` manages it; `fallback_model` is legacy single
  key, `fallback_providers` wins when both present.
- IMPLICATION for seat spawn: chain slide at spawn = the pinned
  provider:model failed NEGOTIATION (unregistered/typo id, missing
  creds), which the runtime reads as an error class and slides the
  chain. The 2026-08-09 evidence matches: `-m gpt-5.6-luna --provider
  openai` rendered flash (chain entry 1 = openrouter flash); `hermes
  models` lists no `gpt-5.6-luna`, so the id is not in the built-in
  catalog as spelled — the picker the owner used presents only
  REGISTERED ids, which is why the manual switch worked.
- THEREFORE the spawn-time guard is: (1) spawn STOPS if the id isn't
  in the picker-validated catalog (fail closed), (2) spawned seats ship
  with `fallback_providers: []` unless the roll explicitly lists one,
  (3) post-spawn probe must match requested id or the seat is flagged
  ERROR and paused — never "close enough".

### P3 — procedural reporting (unchanged) + MCP links
- Per-seat summaries via procedural extraction; local-model summarization
  where fast enough; feeds L2/L3 detectors → strategies → intervention.
- MCP connectivity per 2.4: agents reach Hngh's tools/services through
  the ride-along process.

### P4 — safety + lifespan (unchanged)
Lifespan per seat; wind-down FINAL; prompt-lint gate on every
brief/steer; operation-gate for dangerous classes; hash-chained action
log (card 94) so nobody can make it LOOK like the owner authorized
something they didn't; observation local, no telemetry.

## 4. Anti-goals (known-good doctrine, unchanged)
- No agent runs continually; seats are ephemeral with declared lifespan.
- No LLM in the watch/delivery path (procedural, cheap); LLM only in
  role-bearing seats and optional summaries.
- No hardcoded pane layouts; layouts are data (config + registry).
- No cloud round-trips for observation.
- Delivery is a mechanism, not a dead drop: lane-watch / ride-along
  processes deliver; writing a file proves nothing until read.

## 5. Open decisions (owner)
- Dashboard TUI implementation: Textual Python vs Lisp TUI? (llmtrim
  itself is Python/Textual — check llmtrim's UI library first,
  documentation-first.)
- Window management at startup: which terminal (Konsole)? autostart via
  .desktop or systemd user unit (learned: KDE-generated autostart units
  bite; prefer owned systemd unit).
- Ride-along process initial form: is `seat-up` + `lane-watch` +
  ride-along-log.sh the v1, or does the dashboard TUI itself own the
  panes?

## Attribution
Sanakan (deepseek-v4-flash-0731), hermes TUI, 2026-08-09 — integrating
owner's 10:40 architecture directive verbatim in intent; report to owner
for confirmation before the dashboard build begins.