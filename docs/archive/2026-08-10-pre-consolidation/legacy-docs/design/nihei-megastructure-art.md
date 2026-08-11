# Nihei Megastructure Visual Style & Terminal Specifications

**Author**: Artist (`google/gemini-3.6-flash`)  
**Status**: Active Specification (2026-08-02)  
**Reference**: Tsutomu Nihei (*Blame!*, *NOiSE*, *Biomega*)

---

## 1. Aesthetic Canon

The Hngh user interface is an ancient terminal embedded in the Megastructure.
It is brutalist, structural, high-contrast, and functional.
It was not built to entertain or advertise — it was built to endure ten thousand years without maintenance.

### Core Principles

1. **Monolithic Weight**: High-density block drawing characters (`█`, `▀`, `▄`, `░`, `▒`, `▓`).
2. **Zero Ornamentation**: No rounded corners, no gradients, no pastel colors, no emojis.
3. **Stark Contrast**: Solid black, concrete white, safety yellow (`\e[33m`), hazard orange (`\e[31;1m`), structural cyan (`\e[36m`).
4. **Structural Hierarchy**: Lines are load-bearing walls. Thicker borders denote higher structural authority.
5. **Silence & Scale**: Quiet, dense layouts. No decorative filler or animated sparkle.

---

## 2. ASCII Character Palette

| Character Set | Unicode / ASCII | Purpose |
|---|---|---|
| **Primary Wall** | `█` (U+2588) | Node boundaries, heavy headers |
| **Upper Mass** | `▀` (U+2580) | Top cap of monolithic containers |
| **Lower Mass** | `▄` (U+2584) | Foundation cap of monolithic containers |
| **Conduit / Density** | `░` `▒` `▓` (U+2591..U+2593) | Energy fields, load bars, hazard strips |
| **Frame Double** | `╔` `═` `╗` `║` `╚` `╝` | Core daemon frame, wire protocol boundaries |
| **Frame Single** | `┌` `─` `┐` `│` `└` `┘` | Secondary sub-pane containers |
| **Status Markers** | `[ ✓ ]` `[ ✗ ]` `[ · ]` | Discrete component states |
| **Beam Divider** | `║ ░▒▓█▓▒░ ║` | Gravitational beam / section separator |

---

## 3. Structural Layout Templates

### 3.1 Monolithic Node Frame (`print-nihei-node`)

Used for squad member status, queue tasks, and subsystem health grids:

```
█▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀█
█  NODE // CODER_01                     STATUS: [ ACTIVE ]  █
█  LABEL: Task #83 Session Tree Unit Tests                  █
█  CAPACITY: ░▒▓██████████████████░░░░░░░░░░ [65%]          █
█▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄█
```

### 3.2 Gravitational Conduit Separator (`print-gravitational-beam`)

Used to separate vertical panes or log regions in TUI and daemon outputs:

```
 ║ ░▒▓█▓▒░ ║  MEGASTRUCTURE CORE // SUBSYSTEM_BUS  ║ ░▒▓█▓▒░ ║
```

### 3.3 Industrial Hazard Strip (`format-hazard-bar`)

High-contrast hazard bar for threat detection, budget warning, and rate limits:

```
█░█░█░█░█░█░█░█░█░█░  THREAT DETECTED: HIGH SEVERITY  █░█░█░█░█░█░█░█░█░█░
```

---

## 4. Lisp Utility Integrations (`src/core/ascii-art.lisp`)

The following utilities are exported from `hngh.core.ascii-art`:

```lisp
(hngh.core.ascii-art:print-megastructure-header "DAEMON CORE")
(hngh.core.ascii-art:print-nihei-node "Task Execution" "WORKER_0" "ONLINE")
(hngh.core.ascii-art:print-gravitational-beam)
(hngh.core.ascii-art:format-hazard-bar 32 75)
```

---

## 5. Verification & Acceptance Criteria

1. All ASCII art uses monospace font layout (80 or 120 column alignment).
2. Zero emojis or decorative icons in core TUI, logs, or splash screens.
3. Heavy block rendering (`█`, `▀`, `▄`) used for main structural boundaries.
4. Color scheme strictly adheres to: Concrete White, Safety Yellow, Danger Red, Structural Cyan, Dim Gray.
