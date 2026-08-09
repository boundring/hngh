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
- RESOLVED ROOT CAUSE (2026-08-09, from model-catalog.json): the real
  registered id is `openai/gpt-5.6-luna` served by the OPENROUTER
  provider (`providers.openrouter.models[11].id`, also under `nous`).
  The config's many `provider: openai, model: gpt-5.6-luna` entries are
  internally inconsistent — no bare-`openai` provider serves that id.
  Correct spawn: `--provider openrouter -m openai/gpt-5.6-luna`. This is
  the "bad spec" the owner pointed at; every flash fallback this morning
  traced to it.

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

## 5. Open decisions — RESOLVED (seu, documentation-first, 2026-08-09)

### 5.1 TUI stack: cl-charms (Lisp TUI). NOT Textual, and not llmtrim's UI.
The premise that "llmtrim itself is Python/Textual" is FALSE — verified
from the installed source (Homebrew llmtrim-0.12.5 tarball): llmtrim is a
Rust workspace (crates: llmtrim-core, llmtrim-cli, llmtrim-ledger,
llmtrim-tray, llmtrim-uniffi, llmtrim-wasm). Its dashboard is a Tauri
desktop app — "status-watch" with Overview savings dashboard, Sessions,
Detail, and Sub-routing tabs — plus a Claude Code status line. Nothing
there is reusable in a tmux pane.
- "llmtrim-style" therefore means the INFORMATION ARCHITECTURE of that
  dashboard (overview grid of sessions, per-session detail, a routing/
  config tab), ported to a TUI idiom — not its implementation.
- Hngh's own declaration already points at the stack: hngh.asd future
  deps notes `:cl-charms — for Dashboard TUI upgrade`. Decision: the
  dashboard TUI is a Common Lisp program using cl-charms (ncurses),
  speaking the daemon wire protocol + reading lane files directly.
  Single runtime (SBCL), single test suite, no Python in the product,
  works in a tmux pane.
- Rejected alternative: Textual/Python — second runtime and a separate
  test harness in a CL product for layout convenience; no TUI precedent
  in llmtrim to copy (Tauri is a desktop app, not a pane TUI).

### 5.2 Window management: Konsole + owned systemd user unit.
- Startup window launched by `hngh dash`: `konsole --new-tab` (or a
  dedicated `konsole --separate`) running a tmux pair; the unit owns the
  launch, not KDE's autostart (learned 10:23 — KDE autostart generator
  resurrected the archived `mc`; the generated `app-*-@autostart.service`
  is masked and its .desktop disabled; service-map documents it).
- Unit shape mirrors app-hngh-mc@: `app-hngh-dash@.service` (user),
  ExecStart = konsole/tmux launch; `hngh dash` is idempotent — start or
  attach.

### 5.3 Ride-along initial form: launcher-owned pair; dashboard owns panes later.
- v1 = `seat-up` (two-pane window: Hermes + ride-along, dedicated socket,
  setsid per the 10:22 crash lesson) + `lane-watch` (idle AND dead-seat
  detection, respawn hint never silent auto-respawn) + the ride-along
  pane itself (log tail + steer interface). This is the delivery
  mechanism, matching the day's "delivery is a mechanism, not a dead
  drop" lesson.
- The dashboard TUI OWNS the panes only once it exists (P1 build); until
  then `seat-up` creates the pair and `lane-watch` drives delivery. The
  dashboard reads the same seat registry + lane files + lane-watch log,
  so it is a VIEW over what lane-watch already tracks, not a fork.

## 6. Dashboard TUI spec (llmtrim-style, ported to cl-charms)

Window: one Konsole window, tmux, two panes.
- pane A: paired Hermes session (system config ~/.hermes/config.yaml).
- pane B: `hngh dash` TUI. Full-screen, ncurses.

Pane B layout (data-driven; no hardcoded pane geometry; registry+config
are the source — anti-goal 4):
- HEADER (1-2 rows): role of paired session (the owner's attendant),
  negotiated model (verified, per P2 — banner on ANY requested-vs-
  negotiated mismatch, never quiet), daemon/lane-watch health, clock.
- SEATS LIST (main area): one row per active seat (ALL active agent
  sessions, including the paired one):
  - name (BLAME! registry), role
  - MODEL-TRUTH: requested id + negotiated id side-by-side; mismatch =
    ERROR banner (per P2 fail-closed rule)
  - phase / last activity (from lane files + tmux capture)
  - context % and lifespan (declared per seat)
  - lane state: idle / stalled / DEAD (distinct — lane-watch's dead-seat
    rung feeds this; death is visible, never silently absent) / working
- DETAIL (selectable row): tail of the seat's worklog + outbox, the
  lane-watch log lines for that seat, and its controls:
  - steer (inject /steer via the seat's own tmux socket, care layer:
    check for stranded text → C-u, queue or submit per prompt state)
  - nudge (if idle+unread), respawn hint (if dead; action only when
    config says respawn=yes)
  - pause/close (wind-down FINAL)
- ROUTING TAB (llmtrim's "Sub routing" equivalent): per-seat roll config
  — provider, pinned model id, allowed fallback chain (default: NONE,
  per P2). Editing here rewrites the seat roll; spawn uses it.

Data feed: procedural only (anti-goal 2 — no LLM in the watch path).
Reads: seat-names registry, lane dirs (inbox/outbox/worklog), lane-watch
log, tmux state (capture-pane per seat socket), model-status files,
daemon wire protocol. Write: steer/nudge/respawn via tmux send-keys and
seat-steer; config edits via hngh config API. Summary LLMs (P3) are an
optional overlay, never required for the UI to render.

## 7. Window/layout design — card 102 remaining (seat windows)

Per spawned seat (from `seat-up`, already the in-place launcher):
- ONE terminal window per seat (Konsole), tmux session on dedicated
  socket `tmux -L <name>`, setsid — seat survives spawner shell death
  (10:22 lesson).
- Two panes:
  - pane 1: Hermes session (or Opencode soon) — the agent. Spawned with
    the roll's pinned provider+model id (catalog-verified, fail-closed
    if not registered), `fallback_providers: []` unless the roll lists
    one (P2).
  - pane 2: ride-along — log tail + input/steer interface for the seat;
    usable by human OR Hngh (dashboard/background services) via tmux.
- Post-spawn (P2): probe the negotiated model (cmdline/footer cross-
  check), write model-status, flag mismatch → ERROR + pause. Never let
  a silently-fallen-back seat keep working.
- MCP connectivity (2.4): the window's tmux + ride-along + log + process
  can bridge the agent back to Hngh (hngh-coord's MCP face — registered
  tools: register / post_message / read_inbox / coord-view — is the
  immediate target for the dashboard's own MCP bridge).

Layout rule: all pane geometry is DATA (config + registry), never
hardcoded snippets. `seat-up` reads the roll config; the dashboard reads
the same files; nothing invents its own geometry.

## Attribution
Sanakan (deepseek-v4-flash-0731), hermes TUI, 2026-08-09 — integrating
owner's 10:40 architecture directive verbatim in intent; report to owner
for confirmation before the dashboard build begins.
Seu (deepseek-v4-flash-0731), hermes TUI, 2026-08-09 — §5-7: resolved
the open decisions documentation-first (llmtrim-0.12.5 source =
Rust/Tauri, not Textual; hngh.asd cl-charms declaration), dashboard TUI
spec + window/layout design; verification lane: mirrors verified in
sync at 2717815.