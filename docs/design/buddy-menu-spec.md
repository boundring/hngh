# Pixel-RPG buddy menu spec

Status: DESIGN — P2 contract, 2026-08-27. Ceremony-ready.

Source: [`../project/master-plan.md`](../project/master-plan.md) (DesignPlan
facet: buddy summoned-not-nagging; P6 pixel-art agent surface), the
affinity directive 2026-08-26 (`Operative overlay`, `UX/interface pass`),
[`operative-frames.md`](operative-frames.md) (frame spec),
[`../project/interface-plan.md`](../project/interface-plan.md) (M2
surfaces-on-demand, M4 ask, M5 consider), and the live
[`../../scripts/osd-operative`](../../scripts/osd-operative) QML6 overlay.

Cross-links: [`command-center.md`](command-center.md),
[`gamified-runs.md`](gamified-runs.md),
[`presentation-boundary.md`](presentation-boundary.md),
[`../core/clean-architecture-charter.md`](../core/clean-architecture-charter.md).

## Aesthetic

The buddy is a summoned, non-nagging companion: a small pixel-RPG
operative in a frameless floating window, bottom-right by default. It
exists to be attended, not to demand attention. The operative never
pops up uninvited, never animates in the operator's peripheral focus,
and never interrupts a running surface. Idle means **nearly static**:
a one-frame breathing loop, no motion unless the operator looks.

The operative carries the same dark-coat voice/presence family as the
dashboard surfaces (see
[`assistant-interface.md`](assistant-interface.md)) and renders only
**facts or clearly perceptual flavor** — never a fabricated status.

## Interaction model

One click opens the menu (a compact column beside the operative);
clicking the operative again or clicking away closes it. The menu has
three parts:

1. **Quest ask** — one prompt input box ("quest" ask). Submitting
   routes to the same command underneath as the CLI/GUI control
   contract: it fires a `summon`-style run through create-run →
   admit-transport (S5), or, when prefixed as a consideration
   (`ask:`), routes to the advisory `ask` candidate path (S6). The
   choice + reasons always land in a report row.
2. **Setting toggles** — display-only preferences of the overlay
   itself: state speech on/off, animation intensity (static →
   idle → full), sound on/off, position preset. Toggles never touch
   canonical configuration or any gate input.
3. **Shortcut lenses** — quick views into the spine: queue counts,
   one-line health verdict, next course, latest report tail. Each
   lens is a pure reader over the same `hngh-osd.json` snapshot the
   operative already polls; no lens opens without the operator
   choosing it.

## State-to-animation mapping

Snapshot `state` (computed by the same state machine the
`dashboard-tui` and `osd-operative` share) maps one-to-one onto frame
sets from `evolve-operative` generations. Frame sets are display
assets; nothing in them carries control semantics.

| State | Meaning (facts from the spine) | Animation |
|---|---|---|
| `idle` | queue has queued items, nothing running | near-static breathing loop (1–2 frames) |
| `active` | a session is running | working bustle (2–4 frames, subtle) |
| `thinking` | advisory/consideration report in flight | glancing/hover frame, low motion |
| `alert` | an alert row exists (oversight alert unread) | warning pose + one quiet speech caption, flap-aware |
| `victory` | a ceremony/certificate completed this tick | reward flourish once, then settle to idle |
| `empty` | no queue, no sessions | dormant pose (single frame) |

`alert` and `victory` are **event-driven single transitions**, never
loops: they play once and settle, so the buddy cannot nag. Speech
captions come from the fixed state machine vocabulary; the honesty
leash (see [gamified-runs.md](gamified-runs.md)) applies to any
narrative flavor.

## Technical delivery

- **Renderer:** QML6 frameless floating window
  (`scripts/osd-operative.qml`), launcher `scripts/osd-operative`
  (foreground `--watch N`, `--once`, `--help`).
- **Data:** `/tmp/hngh-osd.json` (override `HNGH_OSD_OUT`), written
  atomically (tmp + rename) by the feeder; the window polls it over
  file:// XHR. Fail closed: an unreadable/missing snapshot keeps the
  last good frame and the window never crashes.
- **Frames:** static per seed from `evolve-operative` (v4,
  `--gen 4 --frames 4 --seed 7`); animation = frame cycling with a
  fixed dwell table, no live re-generation mid-session.
- **No daemon:** `--watch` runs in the operator's foreground session
  tied to a timer/manual launch; the window is a passive poller.
- **Menu data:** menu lenses reuse the same snapshot fields the
  feeder already writes (queue counts, backlog summary, one-line
  status, speech); no new data path until a lens needs it, and any
  new field lands in the snapshot first, then the QML.

## Honesty rules

- The operative renders facts first; flavor only where the state
  machine defines it.
- Menu toggles are overlay-local; they cannot alter canonical state,
  receipts, loadouts, or gates.
- No click path bypasses the control contract: the quest ask and the
  lenses route through the same verbs/gates as the CLI and webapp.
- Anything narrative is tagged `perceptual:true` at the snapshot
  boundary and is display-only (see `gamified-runs.md`).

## Non-goals

- Auto-launch, auto-focus, or any unrequested appearance.
- Anything beyond a click-to-open menu until the command center's
  readouts are trusted (interface-plan slice ordering).
- Sound beyond an explicit toggle; no audio by default.

## Open questions

- Which shortcut lens set is genuinely used first (queue counts vs.
  verdict vs. next course) — build the used one, keep the rest in
  the snapshot.
- Whether quest-ask should support free-text steering into the
  existing `ask` (advisory) lane before `summon` (run firing), and
  what the default is.