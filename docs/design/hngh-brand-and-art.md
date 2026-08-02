# Hngh Brand, TUI Aesthetics & Visual Identity Specification

**Author**: Sisyphus (Artist)
**Date**: 2026-08-02
**Milestone Scope**: M2 (The Companion) & M7+ TUI Polish

---

## 1. Design Philosophy

Hngh is built on SBCL Common Lisp and system-level C primitives. Its visual language mirrors its architecture: **crisp, deterministic, symmetrical, and uncluttered**. We avoid noisy chat bubbles and bloated web UI chrome in favor of high-density terminal interfaces, clean box-drawing characters, and precise ANSI color hierarchies.

---

## 2. Color Palette & ANSI Hierarchy

To maintain readability across light and dark terminal emulators, Hngh TUIs use a restrained 16-color ANSI palette with strict semantic assignments:

| Role | ANSI Code | Hex Equivalent (Reference) | Semantic Meaning |
|---|---|---|---|
| **Primary Accent** | `\033[36m` (Cyan) | `#00BCD4` | Headers, framework identity, interactive prompts |
| **Success / Running** | `\033[32m` (Green) | `#4CAF50` | Active daemons, passing tests, operational health |
| **Warning / Paused** | `\033[33m` (Yellow) | `#FFEB3B` | Degraded state, paused queues, high resource load |
| **Error / Stopped** | `\033[31m` (Red) | `#F44336` | Faults, offline nodes, failed health checks |
| **Muted / Timestamp** | `\033[2m` (Dim) | `#757575` | Event timestamps, secondary metadata, borders |
| **Emphasis** | `\033[1m` (Bold) | — | Section headers, active selections, key metrics |

---

## 3. TUI Box-Drawing Standards

All panel frames and dashboard widgets in `dashboard-tui.lisp` and `mission-control.lisp` adhere to standard UTF-8 box-drawing character blocks:

```text
┌────────────────────────────────────────┐
│ Hngh v0.1.0 — Mission Control          │
├────────────────────────────────────────┤
│ Status: [ RUNNING ]  Daemon: UDS active│
│ Agents: 5 active     Queue: 0 pending  │
└────────────────────────────────────────┘
```

- **Top Corners**: `┌` (`\u250c`), `┐` (`\u2510`)
- **Bottom Corners**: `└` (`\u2514`), `┘` (`\u2518`)
- **Horizontal Rule**: `─` (`\u2500`)
- **Vertical Rule**: `│` (`\u2502`)
- **T-Junctions**: `├` (`\u251c`), `┤` (`\u2524`)

---

## 4. ASCII Banner & Emblem

When spawning interactive sessions or launching the TUI dashboard, Hngh proudly displays a minimal, symmetrical ASCII emblem:

```text
  _   _                       _     
 | | | |_ __   __ _ _ __     | |    
 | |_| | '_ \ / _` | '_ \     | |    
 |  _  | | | | (_| | | | |    | |___ 
 |_| |_|_| |_|\__, |_| |_|    |_____|
              |___/                  
  Common Lisp Agent Orchestrator [v0.1]
```

---

## 5. Companion Avatar Concepts (M2 Preview)

For Milestone 2 (The Companion), assistant avatars rendered in TUI/wayland status widgets follow a modular ASCII glyph set reflecting agent states:

- **Idle / Listening**: `( •_• )`
- **Thinking / Processing**: `( o_o )~`
- **Executing / Working**: `[ ⚡_⚡ ]`
- **Success / Complete**: `( ^_^ )v`
- **Error / Blocked**: `( x_x )!`
