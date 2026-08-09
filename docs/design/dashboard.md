# Mission-Control Dashboard (card 102) — design

**Status**: design (draft by director 2026-08-09; owner-reviewed vision).
**Watchdog lesson driving this**: seats idle silently — director + Killy
both halted at a prompt 2026-08-09 because nothing watched for "seat
stopped making progress." The dashboard's first job is to make halt
VISIBLE, then to make it ACTIONABLE.

## 1. Purpose

One surface for the owner to watch, control, and arrange every agent
session Hngh manages:

1. **Watch** — live view of each seat (TUI pane), its ACTUAL model, brief,
   phase, last activity, context %, coordination-lane state. Owner's
   preference (2026-08-09): "we prefer watching agents work, whenever we
   can, so we can catch mistakes and mix-ups." Hngh automates the
   watching: halt/stall/drift detection without human eyes.
2. **Control** — start/stop/resume seats, inject `/steer` or file-lane
   messages, set per-role model + fallback, use the BLAME! name registry.
3. **Arrange** — tiling and cascading-overlap sizes/positions; tmux
   styling with visible, grabbable borders (the tmux-operations lesson:
   `mouse on` + `pane-border-style fg=cyan`, active yellow bold).
4. **Report** — procedural low-cost summaries of seat progress/actions,
   feeding L2/L3 situation detectors → strategy triggers → intervention.
5. **Lifecycle** — seats are ephemeral by design (lifespan per owner);
   dashboard spawns with a declared lifespan and enforces wind-down.

It replaces the archived `mc`/svc-dash launcher (whose stale autostart
resurrected dead panes every login — the failure mode card 102 exists to
never repeat).

## 2. Substrate decision: tmux + Konsole, data-driven

- **tmux** is the proven substrate (overnight tandem, Apollo/Killy run,
  tmux-operations skill). Sessions = seats; panes = seat TUI + its
  coordination watch. `remain-on-exit on`; dead panes respawn from a
  `pane_cmd <index>` mapping (single source of truth).
- **Konsole** windows attach to tmux sessions for visible observation
  (owner watches Killy live now).
- **Layouts are DATA**: a declarative config (seat list, models, roles,
  lanes, window arrangement) — not a script with hardcoded panes. The
  `mc.archived` anti-pattern: `SVC_DASH_DIR` hardcoded, autostart .desktop
  unmanaged. New model: config file + manager that reads it and a systemd
  user unit / autostart entry that runs the manager idempotently.
- **Names**: `~/.hngh-night/seat-names.md` registry (BLAME! cohort).

## 3. Seat identity truth (the luna lesson, hard-coded)

Pane footer can LIE (shows config default, not the armed model — the
2026-08-09 `gpt-5.6-luna-max` incident: seat ran flash all session while
claiming luna). Dashboard MUST:
- render the model from `/proc/<pid>/cmdline` + a negotiated-model probe,
  never from the footer;
- validate `-m` against config id BEFORE spawn (prompt-lint card 103
  provides the validator);
- record actual model in the lane STATE line, and check drift
  (claimed vs actual) as a situation-detector input.

## 4. Components (decision-complete phases)

### P0 — inventory (already partly done)
Service map: systemd user units (day-ralph, gbd-*, unsloth-studio),
existing plugins (mission-control, sentry, maintenance-coordinator,
config-watcher, file-watcher, emacs-daemon), the seat registry. Output:
`docs/design/service-map.md`.

### P1 — dashboard v1 (tmux-based, llmtrim-style display)
- `hngh dash` command: reads seat config, opens tmux sessions/windows,
  arranges per layout (tiled default; cascade mode), styled borders.
- Dashboard header pane per window: seat name, ACTUAL model, brief id,
  phase, last STATE timestamp, context %, lane state. Refreshed
  procedurally every N seconds (cheap: tmux capture + stat — no LLM).
- Halt detection: seat process alive BUT no lane/context activity for
  > threshold → dashboard marks HALTED and writes a nudge to the lane.
  (The 2026-08-09 halt: both seats paused at prompt; watchdog should
  distinguish "at prompt idle" from "working" and tell the owner, and
  optionally auto-nudge per policy.)
- Lint integration: every brief/steer passes `hngh prompt-lint` before
  send-keys (card 103); lint report shows inline.
- Window arrangement: tmux session geometry + Konsole window positions;
  tiling default, cascade-overlap option (owner's "really valuable
  quality of life").

### P2 — per-role model config
- Hermes profiles (`hermes -p <role>`): per-role config.yaml with model +
  fallback chain. Roles: coder (gpt-5.6-luna), design/review
  (deepseek-v4-flash), PM, etc. Dashboard launcher chooses profile by
  role, validates against known ids, verifies negotiated model post-spawn.
- K3 / frontier tier = strategic reserve; routed only on explicit role
  intent (owner 2026-08-09: "Kimi K3 available now, sparing use; one-off
  code generation requests may route there").

### P3 — procedural reporting (low-cost, local-first)
- Per-seat summary: phase, files touched, commits, lane entries, key
  decisions — via procedural extraction (no remote model): git log
  entries, lane STATE lines, prompt-lint reports. Depth levels.
- Optional local-model summarization (vLLM/ollama) when fast enough /
  queued efficiently — owner accepts local models for summary logging.
- Output feeds L2/L3 situation detectors (context %, halt, drift,
  stall) → strategies → intervention (nudge, lane note, /steer, kill).

### P4 — safety + lifespan
- Lifespan declared per seat at spawn (e.g. `--lifespan 4h` or
  wind-down-time); dashboard enforces FINAL write + wind-down (overnight
  tandem pattern).
- Prompt-lint as the request filter (dangerous-action class refuse +
  operation-gate ref); attribution on every artifact.
- Audit: seats' actions hash-chained (card 94) so nobody can make it
  LOOK like the owner authorized something they didn't — the
  owner's "prevent anyone making agents look illegal" requirement.
- Observation stays local; no telemetry (owner 2026-08-09).

## 5. Anti-goals (known-good doctrine)
- No agent runs continually: every seat is spawned with a lifespan.
- No LLM in the watch/control path (procedural, cheap); LLM only in
  role-bearing seats and optional summaries.
- No hardcoded pane layouts.
- No cloud round-trips for observation.

## 6. Open decisions (owner)
- v1 window target: Konsole (proven, visible) vs plain tmux attach?
  Default: Konsole for observed seats, tmux for batch.
- Halt policy: auto-nudge after N min, or always ask owner?
  Default: warn at 5 min, nudge via lane at 10, kill only on explicit
  owner or exhausted lifespan.
- Which services in P0 scope: day-ralph, gbd-*, unsloth-studio, and the
  hermes gateway — confirm.

## Attribution
Directors/reviewers name producer agent+model. Draft: director
(deepseek-v4-flash-0731), hermes TUI, 2026-08-09.