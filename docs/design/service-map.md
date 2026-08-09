# Service map (card 102 P0) — Hngh-managed services & seats

Snapshot 2026-08-09 10:25. Procedural inventory; source of truth for the
mission-control dashboard v1 (docs/design/dashboard.md).

## Agent seats (BLAME! registry ~/.hngh-night/seat-names.md)

| Seat | Model (actual) | Lane | State |
|---|---|---|---|
| Sanakan (director/coord) | deepseek-v4-flash-0731 | tandem-apollo/director-* | active, hermes TUI |
| Killy (coder) | gpt-5.6-luna | tandem-apollo/apollo-* | active, card 103 done, on make-check |

Seat lifecycle: ephemeral, declared lifespan, wind-down FINAL, name freed
on close. Delivery via lane-watch driver (never dead drops).

## Systemd user units (relevant; filtered of KDE/app noise)

| Unit | State | Purpose / notes |
|---|---|---|
| day-ralph.service | inactive | Hngh Day-Ralph (local-model planning loop) — off-schedule |
| gbd-agent-configs.service | **failed** | agent-configs backup — needs diagnosis |
| gbd-hermes-mcp-proxy.service | inactive | MCP proxy for hermes — 332B stub |
| gbd-hermes-mcp-proxy.timer + .path | present | watchdog wiring for the above |
| gbd-hermes-nous-off.service (+ shutdown) | inactive | hermes nous-off backup |
| unsloth-studio.service | active | Unsloth Studio (GPU/local LLM workbench) |
| unsloth-warm.service | inactive | warm-pin helper |
| app-hngh-mc@autostart.service | **masked (this pass)** | KDE autostart generator resurrecting archived mc — ExecStart=`alacritty -e ~/.local/bin/mc`; stop+masked 2026-08-09 10:23; source .desktop disabled |
| app-svc-dash@autostart.service | inactive | archived svc-dash era |

## Coordination substrate (~/.hngh-night/)

- tandem-apollo/: inbox/outbox lanes, worklog, benchmark-log, FINALs
- tasks/: deck cards (95, 98, 102, 103 — 103 DONE)
- seat-names.md registry

## What the dashboard surfaces with this map

1. failed units (gbd-agent-configs) — visible at a glance
2. masked/vestigial autostart generators (hngh-mc) — flagged as stale
3. seat halt/idle state — corrected model + last activity
4. delivery: lane-watch nudges (see ~/.hngh-night/tandem-apollo/lane-watch.log)

## Open (dashboard P1 will close)
- Diagnose gbd-agent-configs failure (next service-maintenance pass).
- Decide day-ralph schedule (inactive by design or dormant?).
- MCP proxy stub: wire or retire.

Attribution: Sanakan (deepseek-v4-flash-0731), hermes TUI, 2026-08-09.