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

## 8. Ride-along console + agent back-channel (owner 12:45, holistic)

The ride-along pane is not a passive tail — it is the seat's interactive
console, and the agent connects back to Hngh the same way the dashboard
does: MCP tools, tmux dispatch, file lane. One window, three
bidirectional channels.

### 8.1 Current state (audited 2026-08-09)

- Ride-along pane command is `echo; tail -F worklog.md & wait` — it
  DISPLAYS the lane but has NO stdin routing. Typed lines go nowhere.
  The pane's "type a line => steer to seat" claim is aspirational.
- hngh-coord MCP face exists and is wire-proven (card 101): tools
  `register`, `post_message`, `read_inbox`, `status`, `steer` over
  newline-delimited JSON (`~/.local/bin/hngh-coord-mcp` stdio
  server). Registered in `~/.hermes/config.yaml`; Hermes discovery,
  test, and list all pass with five tools enabled.
- tmux dispatch works (seat-steer care layer, lane-watch nudge): the
  dashboard's control path is real. The agent->Hngh path is now active.

### 8.2 Design: the ride-along console (pane 2, owned by dashboard later)

One process, three functions, stdin-routed by prefix — a small
`ride-along` script (replaces the inline `tail -F & wait`):

```
Display (stdout)   tail -F worklog.md + outbox tail + model-status
                   + lane-watch log lines for this seat
Input (stdin)      plain line        -> append to own worklog
                   ack <lane/text>   -> append ACK to <lane>/inbox.md
                   steer <seat> ...  -> seat-steer <seat> "..."
                   status            -> print seat-truth (model, phase,
                                        lanes, last activity)
                   mcp ping          -> run a local-hook MCP probe
                   help              -> command list
                   (Ctrl-C exits the ride-along, not the seat)
```

Routing is implemented against the file lane and tmux sockets the
dashboard already uses — no new wire. Prefix parsing is a ~30-line
function; fixture-testable with the existing fake-tmux harness plus a
fake lane dir. Human and Hngh can both drive it (same input path); the
DASHBOARD owns the pane once P1 lands, per §5.3.

INPUT GATING (Cibo review 12:55):
- `ack <lane>` accepts only KNOWN lanes (registry-derived target list),
  never arbitrary paths — append-only to the sibling's inbox, never
  overwrite (the 11:05 lane-clobber lesson).
- Every routed line passes prompt-lint before dispatch (card 103, no
  LLM): steers and acks are briefs; the same gate that checks seats'
  briefs applies here. Failed lint → dropped with a message in the
  ride-along, never silently forwarded.
- All writes go through the append helper (`lane-append`) and land a
  breadcrumb (durable-coordination-records.md §4); every steer that
  dispatches also writes a COORD JOURNAL record (kind "steer") so the
  dashboard's per-seat steer history is data, not prose archaeology.

COLLISION-AWARE DISPATCH (durable-coordination-records.md §8, owner
15:13):
- Before `steer <seat> ...` or `ack <lane> ...` dispatches, consult
  `~/.hngh-night/state/claims.lisp`. If the TARGET surface is claimed
  by another seat mid-build (e.g. a steer asking a seat to edit
  `script:hngh-live-watch` while cibo holds that claim), do NOT send
  the raw steer: surface it as a QUEUED PENDING note in the ride-along
  with the holder's name, and land a WAIT-GATE line naming the claim.
  The watcher re-wakes when the holder's lane moves (serial
  execution, §8.2 rung 2).
- `status` and `help` are read-only, never blocked by claims.
- Plain worklog appends are the seat's own surface — never claim-
  blocked; the seat writes its own lane.

### 8.3 Design: agent back-channel (MCP first, tmux + lane fallback)

STATUS: ACTIVE — `hngh-coord-mcp` is registered as `hngh` in
`~/.hermes/config.yaml` with five tools enabled. Independent newline
wire probe, `hermes mcp add`, `hermes mcp test`, and `hermes mcp list`
all pass. The registration is now part of the working-group wave.

The current design has three channels. The eventual back-channel count
is N: it grows with the coordination surfaces Hngh actually supports.

Agents connect back to Hngh through THREE channels, in order:

1. **MCP (tool-level, primary)**: registered as `hngh` in the local
   Hermes config (`hermes mcp add hngh --command
   /home/bricker/.local/bin/hngh-coord-mcp`; connect-timeout 120 for
   the SBCL boot). Each Hermes session can expose `mcp__hngh__*` tools.
   post findings, read their inboxes, steer siblings — via tools, from
   inside any session, no tmux knowledge needed.
   TOOL ALIGNMENT (Cibo review 12:55): the exposed set is
   `register`, `post_message`, `read_inbox`, `status`, `steer`
   (source: coord.lisp tools/list). The old "coord-view" name in §7 is
   superseded by `status`; do not cite coord-view. Schema drift is
   live — verify each tool's args against coord.lisp before building
   on it (register role key; post_message target; read_inbox me).
2. **tmux dispatch (UI-level)**: seat-steer / lane-watch nudge — the
   dashboard's existing control path; used for steers and nudges where
   a live prompt matters more than a message. MCP `steer` and tmux
   seat-steer are DIFFERENT channels: MCP steer = durable note in the
   coord journal; tmux seat-steer = live input to a running seat.
   Do not conflate them in the UI.
3. **File lane (durable, crash-surviving)**: inbox/outbox/worklog —
   canonical for anything that must outlive a session (crash-resume
   works because the lane survived).

Rule (from §2.4, made concrete): MCP for tool/message-level control,
tmux for UI-level control, file lane for durable coordination. A seat
uses whichever fits the action; the dashboard reads all three.

### 8.4 Skills as the agent-side adapter

Ship one Hermes skill (`hngh-lane`) teaching an agent the contract:
read your inbox, post to outbox, ack via lane or `mcp__hngh__*`,
report model truth. Skills make MCP tools discoverable and keep agent
sessions cheap (no need to reverse-engineer the lane layout per
session). This is the same adapter role `misakanet` plays for the
failure-memory shield.

### 8.5 Build order (adds to P1/P3)

- P1: `ride-along` console script + fixture; register hngh MCP server
  (owner runs the config edit); seat-up starts the console instead of
  inline tail.
- P3: `hngh-lane` skill; dashboard MCP bridge uses the registered
  server (already in §7); summary LLM overlay may post findings via
  `post_message` instead of dead-dropping files.
- Verify per surface: `hermes mcp test hngh` (real tool call), ride-
  along stdin routing fixtures, lane-watch still reads seats.

## Attribution
Sanakan (deepseek-v4-flash-0731), hermes TUI, 2026-08-09 — integrating
owner's 10:40 architecture directive verbatim in intent; report to owner
for confirmation before the dashboard build begins.
Seu (deepseek-v4-flash-0731), hermes TUI, 2026-08-09 — §5-7: resolved
the open decisions documentation-first (llmtrim-0.12.5 source =
Rust/Tauri, not Textual; hngh.asd cl-charms declaration), dashboard TUI
spec + window/layout design; verification lane: mirrors verified in
sync at 2717815.
Seu (deepseek-v4-flash-0731), hermes TUI, 2026-08-09 — §8: ride-along
console + agent back-channel (owner 12:45 holistic direction) —
ride-along stdin routing, hngh-coord MCP registration, three-channel
rule + hngh-lane skill adapter, build order into P1/P3.
Seu (deepseek-v4-flash-0731), hermes TUI, 2026-08-09 — §8 amended
13:00 (Cibo review 12:55 + Killy source-verdict): MCP STATUS=PLANNED
until owner runs `hermes mcp add` + independent wire test; tool
alignment (status supersedes coord-view; verify args per coord.lisp);
MCP steer vs tmux seat-steer distinguished; ride-along input gating
(known-lane append-only + prompt-lint).Seu (deepseek-v4-flash-0731), hermes TUI, 2026-08-09 — §8 input-gating
extended 13:15 (owner durable-records doctrine): writes via lane-append
helper + breadcrumb; steer dispatch writes COORD JOURNAL (kind steer)
for data-driven steer history (durable-coordination-records.md §4/§2).
