# Hngh Terminal Styling Guide — Megastructure Edition

**Author**: Sisyphus (Artist / Atlas Plan Executor)
**Date**: 2026-08-02
**Audience**: Designers and Coders working on Hngh TUI surfaces
**Brand Reference**: `docs/design/hngh-brand-and-art.md`

---

## 1. Font Requirements

Hngh TUIs require a monospace font with the following glyph coverage:

| Glyph Class | Characters | Required For |
|---|---|---|
| **Box Drawing** | `╔ ═ ╗ ║ ╚ ╝ ╠ ╣ ╦ ╩ ╬` | Megastructure headers, bulkhead frames |
| **Block Elements** | `█ ░ ▒ ▓` | Buffer fill bars, progress indicators |
| **Geometric Shapes** | `● ○ ◉ ◎` | Status dots, health indicators |
| **Arrows** | `→ ← ↑ ↓ ↔` | Data flow diagrams, navigation hints |
| **CJK / Emoji Safety** | `🗼 ⚙️ 👾 🛡️ 🔦 🌀` | Emblem accents (non-essential) |

### Recommended Fonts

| Font | Coverage | Terminal Support |
|---|---|---|
| **IBM Plex Mono** | Full (boxes, blocks, arrows) | Excellent — Hngh's primary recommendation |
| **Iosevka** | Full + narrow variants | Excellent — best for split-pane layouts |
| **Fira Code** | Full (no ligatures needed) | Good — ligatures won't interfere |
| **Source Code Pro** | Box drawing only (no blocks) | Adequate — block chars fall back to `#` |
| **Hack** | Box drawing only | Adequate — same fallback |

### Fallback Strategy

```
If any glyph renders as □ or empty:
  1. Try: set terminal to "UTF-8" encoding
  2. Fall back: replace double-line boxes (╔═╗) with single-line (┌─┐)
  3. Fall back further: replace single-line with ASCII (+--+)
  4. Emojis are OPTIONAL — never required for core functionality
```

---

## 2. ANSI Color Testing

### Required Terminal Palette Verification

Hngh's Blame! palette depends on these ANSI codes rendering correctly:

| Code | Color | Bad Terminal Appearance | Expected |
|---|---|---|---|
| `\033[36m` | Cyan | Washed-out blue, near-white | Distinct bright cyan |
| `\033[32m` | Green | Yellowish, olive | Clear bright green |
| `\033[33m` | Yellow | Brown, orange | Distinct bright yellow |
| `\033[31m` | Red | Dim brownish-red | Clear bright red |
| `\033[2m` | Dim | No visible difference | Noticeably muted |

### Test Command

```bash
printf '\033[36mCYAN Megastructure Beam\033[0m\n'
printf '\033[32mGREEN Silicon Life\033[0m\n'
printf '\033[33mYELLOW Safeguard Caution\033[0m\n'
printf '\033[31mRED Exterminator Alert\033[0m\n'
printf '\033[2mDIM Concrete Shadow\033[0m\n'
```

If any line appears indistinguishable from white/black text, the terminal's
color palette needs adjustment before Hngh TUI use.

---

## 3. Layout Disciplines

### Panel Spacing

```
[HEADER]          ← 2-line double-box frame (╔══╗)
 (blank line)
[CONTENT]         ← indented 2 spaces from frame edge
 (blank line)
[FOOTER]          ← dim-text navigation bar
```

Never collapse spacing between panels — the megastructure breathes through
deliberate negative space. Crowded panels are a Safeguard violation.

### Column Width

All TUI views target **80 columns minimum**. The `render-header` double-line
box is exactly 80 columns wide. Any view that exceeds 80 columns on a standard
terminal must be refactored to fit.

### Pane Splits for mc/mission-control

```
┌─────────────────────┬──────────────┐
│ svc-dash / daemon   │ status       │
│ (primary workspace) │ (health)     │
│                     ├──────────────┤
│                     │ events       │
│                     │ (feed)       │
├─────────────────────┴──────────────┤
│ free agents / terminal             │
│ (bottom bar, tall)                 │
└────────────────────────────────────┘
```

Golden ratio approximation: left pane ~60%, right column ~40%, bottom bar ~25% height.

---

## 4. Typography Hierarchy

| Level | Style | ANSI | Use |
|---|---|---|---|
| **H1** | BOLD CYAN UPPERCASE | `\033[1;36m` | Megastructure header titles |
| **H2** | Bold White Mixed Case | `\033[1m` | Section titles (Components, Events) |
| **Body** | Normal White | `\033[0m` | All informational text |
| **Meta** | Dim White | `\033[2m` | Timestamps, help text, borders |
| **Alert** | Bold Red / Yellow / Green | `\033[1;31m` etc. | Status indicators |
| **Code** | Cyan Normal | `\033[36m` | Lisp symbols, paths, commands |

### Anti-Patterns

- **NO** mixed case in header: `Hngh Megastructure` → `HNGH MEGASTRUCTURE`
- **NO** color-for-color's-sake: every color conveys semantic state
- **NO** blinking text: ANSI blink codes are an Exterminator-class offense

---

## 5. Accessibility

### Contrast Ratios (WCAG AA target)

| ANSI Pair | Approx Ratio | Status |
|---|---|---|
| Cyan (#00BCD4) on Black (#000000) | ~7:1 | **Pass** |
| Green (#4CAF50) on Black | ~5:1 | Pass |
| Yellow (#FFEB3B) on Black | ~12:1 | Pass |
| Red (#F44336) on Black | ~4.5:1 | Borderline — use Bold Red for critical alerts |
| Dim (#757575) on Black | ~3:1 | Fail for body text, pass for non-essential metadata |

### Colorblind-Friendly Encoding

Never rely on color alone to convey state. Each status indicator must have
a secondary text label:

```
OK:  "🟢 RUNNING"       not just "🟢"
Warn: "🟡 PAUSED"       not just "🟡"
Error: "🔴 STOPPED"     not just "🔴"
```

The word label is the primary indicator; the color/glyph is reinforcement.

---

## 6. Asset Checklist for M2

These visual assets should exist before M2 (The Companion) ships:

- [ ] **Startup Splash**: `megastructure-banner` executed on daemon start
- [ ] **Help Panel Glyphs**: Roguelike help modal with all keybindings
- [ ] **Level Map**: Floor-descent ASCII map for Megastructure view
- [ ] **Buffer Bar Component**: Reusable `buffer-fill-bar` for any view
- [ ] **Status Dash Component**: Standardized `[ GREEN LABEL ]` for component health
- [ ] **Event Severity Icons**: Consistent glyph+color pairs per severity class
- [ ] **Companion State Glyphs**: M2 avatar expressions (idle, thinking, executing, error)
