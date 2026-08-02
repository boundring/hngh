# Hngh Megastructure — Component Architecture

```
          ╔══════════════════════════════════════════════════════════╗
          ║                H N G H   M E G A S T R U C T U R E      ║
          ║                C O M P O N E N T   L A Y O U T          ║
          ╚══════════════════════════════════════════════════════════╝

                          ┌─────────────────────┐
                          │     hngh-client     │
                          │  (CLI / Emacs / TUI) │
                          └──────────┬──────────┘
                                     │ SEXP-over-UDS
                          ┌──────────▼──────────┐
                          │   hngh-daemon        │
                          │  ┌────────────────┐  │
                          │  │ wire-protocol  │  │
                          │  └───────┬────────┘  │
                          │          │           │
            ┌─────────────┼──────────┼───────────┼─────────────┐
            │             │          │           │             │
     ┌──────▼──────┐ ┌───▼───┐ ┌───▼───┐ ┌─────▼─────┐ ┌─────▼─────┐
     │ scheduler   ││ event ││ state ││plugin-host││supervisor │
     │  (A5/A6)    ││  bus  ││ store ││   (A1)    ││   (A6)    │
     │┌───────────┐││ (A2)  ││ (A3)  ││┌─────────┐││┌─────────┐│
     ││ timers    │││pub/sub││ sqlite│││ manifests│││ restart ││
     ││ schedules │││ events││ trees │││ isolation│││ health  ││
     ││ ticks     │││filter ││ locks │││ loading │││ watchers ││
     │└───────────┘││       ││       ││└─────────┘││└─────────┘│
     └──────┬──────┘ └──┬───┘ └───┬───┘ └─────┬─────┘ └─────┬─────┘
            │           │         │           │             │
            └───────────┼─────────┼───────────┼─────────────┘
                        │         │           │
        ╔═══════════════╪═════════╪═══════════╪═══════════════════╗
        ║ FIRST-PARTY   │         │           │  PLUGINS          ║
        ║               │  ┌──────▼──────┐    │                   ║
        ║ ┌─────────────┴──┤ai-orchest.  │    ├──────────────┐    ║
        ║ │                │(B3)         │    │              │    ║
        ║ │                │ ┌──────────┐│    │ ┌──────────┐ │    ║
        ║ │                │ │task queue││    │ │dashboard │ │    ║
        ║ │                │ │eligibility││   │ │TUI (B9)  │ │    ║
        ║ │                │ │leases    ││    │ │overview  │ │    ║
        ║ │                │ │handoffs  ││    │ │events    │ │    ║
        ║ │                │ └──────────┘│    │ │plugins   │ │    ║
        ║ │                └──────┬───────┘    │ │megastruct│ │    ║
        ║ │                       │            │ └──────────┘ │    ║
        ║ │  ┌────────────────────▼──────────┐ │              │    ║
        ║ │  │        ai-tool-hub  (B11)     │ ├──────────────┘    ║
        ║ │  │  opencode|claude|codex|gemini │ │                   ║
        ║ │  │  anthropic|google|openai|local│ │ ┌──────────┐      ║
        ║ │  └──────────────┬───────────────┘ │ │mission   │      ║
        ║ │                 │                 │ │control   │      ║
        ║ │  ┌──────────────▼───────────────┐ │ │(M6)      │      ║
        ║ │  │   model-runtime  (B4)        │ │ │tmux tiled│      ║
        ║ │  │  ollama|llama.cpp|unsloth    │ │ │subagent  │      ║
        ║ │  │  comfyUI|systemd lifecycle   │ │ │summon    │      ║
        ║ │  └──────────────────────────────┘ │ └──────────┘      ║
        ║ │                                   │                   ║
        ║ │  ┌────────┐ ┌───────┐ ┌────────┐  │ ┌──────────┐      ║
        ║ │  │backup  │ │secrets│ │package │  │ │hnghbeats │      ║
        ║ │  │(B7)    │ │(B8)   │ │man.(B1)│  │ │(B6)      │      ║
        ║ │  │git sync│ │vault  │ │pacman  │  │ │daily     │      ║
        ║ │  │restore │ │secrets│ │yay/paru│  │ │condense  │      ║
        ║ │  └────────┘ └───────┘ └────────┘  │ └──────────┘      ║
        ║ │                                   │                   ║
        ║ │  ┌────────────┐ ┌────────────┐    │ ┌─────────────┐   ║
        ║ │  │knowledge   │ │threat-det. │    │ │system-config│   ║
        ║ │  │base (B12)  │ │(B5) LLM    │    │ │(B2)         │   ║
        ║ │  │articles    │ │review+L2   │    │ │/etc managed │   ║
        ║ │  │search      │ │periodic    │    │ │snapshots    │   ║
        ║ │  └────────────┘ └────────────┘    │ └─────────────┘   ║
        ║ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─│                   ║
        ║   M7: daemon ←── wire protocol ──→ client               ║
        ║   M8: model-management (planned)                         ║
        ╚══════════════════════════════════════════════════════════╝

        DATA FLOW LEGEND
        ───────────────
        ────►  task submission / delegation
        ◄───  event publication
        ════  SEXP wire protocol (daemon ↔ client)
        ····  dbus bridge to systemd session bus

        CORE → ai-orchestrator: tasks flow DOWN, events flow UP
        ai-orchestrator → ai-tool-hub: delegate tasks to tool invocations
        ai-tool-hub → model-runtime: route to local/remote endpoints
        model-runtime → ai-tool-hub: return results with cost metadata
        ai-orchestrator → event-bus: publish complete/block/fail events
        event-bus → hnghbeats: daily condensation of event stream
        scheduler → ai-orchestrator: tick-driven task dispatch
        state-store ↔ all: persistent file tree with sqlite locks
```
