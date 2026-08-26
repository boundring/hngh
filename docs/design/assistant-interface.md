# Assistant interfaces — the operative layer

Hngh's operator-facing surfaces should feel like *being in a Nihei
book*: slender, tall, faceless figures; harsh minimal linework; the
quiet of a megastructure. The operative is not a mascot with a face —
it is a presence: a dark coat silhouette, a slit where a face might
be, speech that arrives like a caption in the margin. Fantasy and
sci-fi both (Tower Dungeon's stone, Blame!'s silicon).

## Aesthetic principles

1. **Slender and elegant, never cute.** Sacrifice facial features
   freely; the absence *is* the design. A clean dark figure against
   the panel edge reads stronger than any expression.
2. **The record is the atmosphere.** The operative speaks in evidence:
   "The queue holds its breath." "A cycle turns." "Sealed with a
   certificate — that is how the world ends quietly." Lines are
   one or two sentences, state-driven, never chatter.
3. **Keyword presence.** Domain words (`rotation`, `candidate`,
   `certificate`, `heartbeat`, `wake`) carry color and, later,
   hover/tool-tip definitions in the overlay.
4. **Motion is rare and meaningful.** A blink of the eye-slit, a coat
   hem shift on state change. Stillness is the default; movement is
   information.
5. **Practice the aesthetic.** The local image-gen lane (comfyui is
   installed) exists precisely to mock and iterate: generate
   character studies, palette chips, frame test sheets, and fold the
   good ones into the sprite assets. Quantity first; the canon
   emerges from the pile.
6. **The operative is a standardized two-arm / two-leg rig, recognizable
   as a person at a glance.** Not a ball-headed or coat-shape sprite: the
   figure has EXACTLY two arms (each a distinct upper arm + lower arm with
   a visible elbow bend) and EXACTLY two separated legs (thigh + shin +
   boot, with a clear gap between them), in a symmetric default pose —
   central vertical axis, bilateral symmetry, balanced 1:1:1 head-torso-
   legs proportion. The small head carries a flat eye-slit with a `•` mote,
   and there is a visible shoulder line. The art leans on artistic finesse
   techniques: anti-aliased `▒` feathering on all diagonals, motion-blur
   `░` drag-tails, squash-and-stretch on breath, anticipation before a
   motion, staggered limb travel, a secondary edge light, interior shading
   (a `▓▒░` gradient), a persistent eye-slit mote, and a ground contact
   shadow that shifts with the motion. Animation runs 6-8-frame loops with
   clearly distinct poses at 0.3-0.5 s — walk-cycle-style weight transfer,
   arm-raise gestures, blink, and breathe. The reference breed is
   `scripts/evolve-operative --gen 5` (families in the operative-frames
   catalog); the TUI consumes its frame sheets via `AnimatedSprite`.

## Current state (committed)

- `scripts/dashboard-readout` watch mode renders the operative above a
  state-driven speech bubble, framed panels for queue/timeline/
  sessions, keyword highlighting, width-aware layout, `q`/ESC quit,
  cursor discipline, and graceful fallback (stdlib `--plain`) when
  `rich` is absent. Terminal TUI today; the same content is the
  overlay tomorrow.
- Speech lines live in `SPEECH` (idle/active/done/empty); the art in
  `KILLY` — a tall coat, faceless.

## Terminal TUI (landed)

- Library: `rich` (user-site install; CachyOS also carries
  `python-rich` in repos). `textual` (in CachyOS repos) is the next
  step for reactive widgets: scrollable transcript, clickable
  keywords, modal explanations — the pop-in/tool-tip layer the
  operator asked for.
- `--plain` forces the stdlib renderer; the gate tests both.

## Desktop overlay (Plasma 6, researched)

The overlay assistant floats above everything. On this Xorg box the
correct Plasma 6 recipe is a **standalone qml6 window**, not a
plasmoid (a desktop plasmoid draws *under* windows):

- Frameless always-on-top transparent window:
  `flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint`
  with `color: "transparent"`; `Qt.WindowTransparentForInput` makes it
  click-through; a KWin script adds force-on-top semantics if needed.
- Runs with `qml6 file.qml` (qt6-declarative, present on this box).
- Animations: `AnimatedSprite` (spritesheet: frameCount/frameWidth/
  frameHeight/frameRate, `loops: Qt.Infinite`) for the operative's
  frames; `AnimatedImage` for GIF exports.
- Widget path (alternative): `~/.local/share/plasma/plasmoids/`
  package with `metadata.json` (`X-Plasma-API-Minimum-Version:
  "6.0"`), `contents/ui/main.qml` with `PlasmoidItem`, and
  `contents/config/config.qml`; reload via `killall plasmashell`.
- Wayland-only sessions would need layer-shell or a KWin effect; this
  machine is X11, so the qml6 path applies now.

## Voice (local, character-driven)

Direction: local neural TTS (piper or kokoro-82m — see the
tts-research record when it lands) per character: 3–5 distinct
voices, one per operative persona; playback through `paplay` against
PipeWire; STT (whisper.cpp / sherpa-onnx) for the operator side with
VAD for push-to-talk. Speech is a surface, never a gate: the record
stays textual and the voice is a rendering of it.

## Feedback loops

Every iteration of the operative layer is shown live to the operator
(terminal tour, then overlay) and committed through the ceremony — the
loop is the product. The federated-governance vision (validating
successful operator UI/UX examples across the mesh) is a later rung;
today the iteration loop is the seed.

## Interface family & mock matrix

Hngh is an interface *family*, not one TUI. We mock and iterate each
surface incrementally, one slice at a time, alongside the automated
grading loop (`scripts/grade-interface`).

- **Compact llm-trim-style panels** — menubar/card popovers; simple,
  practical, slick, elegant. State: mocked (concept). Next increment:
  one compact panel mock.
- **Terminal TUI (textual)** — the current `dashboard-tui`/readout
  surfaces. State: landed (`rich`; `textual` next). Next increment:
  the animated pixel operative.
- **KDE qml6 overlay operative** — floating sprites, speech, buttons,
  scrolling text over the desktop. State: researched. Next increment:
  build the standalone qml6 window + sprite sheet.
- **Web dashboard** — the existing `--export-html`. State: landed.
  Next increment: reuse the grade loop against it.
- **Emacs-style extensible surface** — the operative as an extensible
  operator surface. State: backlog (`ux-hardening`). Next increment:
  define the extension model.
- **Local voice (TTS/STT)** — character voices, push-to-talk. State:
  backlog (`operative-voice`). Next increment: pick the TTS engine.

## Backlog hooks

- `dancing-ui` — interfaces that move with music (audio-intensity is
  live; the operative can lean into the beat).
- `ux-hardening` — Emacs-style extensible operator surface; the
  operative is its face.
- New: `assistant-overlay` — the qml6 desktop operative (sprites,
  speech, buttons, scrolling text).
- New: `assistant-voice` — local TTS/STT character voices.
- New: `assistant-image-lane` — comfyui practice loop for aesthetic
  canon (character studies, palettes, frame sheets).
