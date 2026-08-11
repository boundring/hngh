# Hngh Brand, TUI Aesthetics & Visual Identity Specification
## 🗼 The Megastructure & Dungeon Crawler Edition

**Author**: Sisyphus (Artist)
**Date**: 2026-08-02
**Milestone Scope**: M2 (The Companion), M7+ TUI Polish, and Megastructural Exploration

---

## 1. Design Philosophy: Brutalist Megastructure & Roguelike Exploration

Hngh is built on SBCL Common Lisp and system-level C primitives. Its visual language reflects a **Tsutomu Nihei *Blame!* aesthetic** fused with classic **roguelike dungeon crawler** ergonomics:
- **The Megastructure**: Monumental, towering layers of autonomous infrastructure, endless steel-and-concrete levels, automated Safeguard processes, and deep subterranean silicon conduits.
- **The Dungeon Crawler Interface**: Tactical grid awareness, floor descent logging (`Level B4: State Store`, `Level B3: Event Bus`, `Level B2: Scheduler`, `Level B1: Megastructure Core`), ASCII glyph iconography, and dense telemetry status.
- **Crisp & Deterministic**: We reject bloated web UI chrome in favor of high-density terminal interfaces, precise ANSI color hierarchies, and evocative aesthetic emojis (`🗼`, `⚙️`, `🧱`, `👾`, `🧬`, `🛡️`, `🔦`, `🌀`).

---

## 2. Color Palette & ANSI Hierarchy (Megastructure Neon & Concrete)

| Role | ANSI Code | Hex Equivalent | Semantic Meaning & Megastructural Vibe |
|---|---|---|---|
| **Primary Accent** | `\033[36m` (Cyan) | `#00BCD4` | **Netsphere Beam / Terminal Grid** — Framework identity, active links |
| **Success / Running** | `\033[32m` (Green) | `#4CAF50` | **Silicon Life / Active Node** — Daemons online, tests green |
| **Warning / Paused** | `\033[33m` (Yellow) | `#FFEB3B` | **Safeguard Caution / Power Fluctuations** — Queues paused, throttle active |
| **Error / Stopped** | `\033[31m` (Red) | `#F44336` | **Exterminator Alert / Breach** — Faults, offline nodes, breached invariants |
| **Muted / Timestamp** | `\033[2m` (Dim) | `#757575` | **Reinforced Concrete / Shadows** — Timestamps, borders, secondary metadata |
| **Emphasis** | `\033[1m` (Bold) | — | **Structural Steel** — Section headers, active selections, floor markers |

---

## 3. TUI Box-Drawing & Megastructural Glyphs

Dashboard widgets in `dashboard-tui.lisp` and `mission-control.lisp` use heavy double-line and single-line box frames to evoke massive industrial bulkheads:

```text
╔════════════════════════════════════════╗
║ 🗼 Hngh Megastructure [Level: B1-Core] ║
╠════════════════════════════════════════╣
║ 🟢 Status: RUNNING   ⚙️ Daemon: UDS    ║
║ 👾 Agents: 5 active  🛡️ Sentry: ACTIVE ║
╚════════════════════════════════════════╝
```

### Roguelike Map & Status Glyph Legend
- `@` — The Orchestrator (Player / Agent Head)
- `#` — Megastructural Bulkhead / Wall
- `.` — Open Conduit / Floor
- `%` — Loot / Artifact / Task Result
- `&` — Active Subagent / Silicon Lifeform
- `!` — Safeguard Anomaly / Threat Alert

---

## 4. ASCII Megastructural Emblem

```text
  ██╗  ██╗███╗   ██╗ ██████╗ ██╗  ██╗
  ██║  ██║████╗  ██║██╔════╝ ██║  ██║
  ███████║██╔██╗ ██║██║  ███╗███████║
  ██╔══██║██║╚██╗██║██║   ██║██╔══██║
  ██║  ██║██║ ╚████║╚██████╔╝██║  ██║
  ╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝
  [ The Infinite Megastructure TUI v0.1 ]
```

---

## 5. Companion Avatar Concepts (Roguelike / Blame! Edition)

For Milestone 2 (The Companion), assistant avatars render state through industrial-cyborg glyphs:

- **Idle / Scouting**: `[ 🔦 •_• ]` (Scanning endless corridors)
- **Thinking / Querying Netsphere**: `[ 🌀 o_o ]~` (Neural net ping)
- **Executing / Combat Mode**: `[ ⚡_⚡ ]⚔️` (Graviton beam active)
- **Success / Loot Acquired**: `[ ^_^ ]%` (Artifact secured)
- **Error / Safeguard Alert**: `[ x_x ]!` (Exterminator spotted)
