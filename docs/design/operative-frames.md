# Operative frames — evolutionary pixel-art catalog

Bred by `scripts/evolve-operative`: a seeded mutation walk over a block-char
humanoid template. Every frame is monospace-safe (≤24 cols, ≤18 rows), drawn
only from `█ ▀ ▄ ░ ▒ ▓ ▐ ▌ ▗ ▖ ▝ ▘ •` + spaces, and deterministic per seed.

Base silhouette (`idle-0`, identical across seeds): slender, faceless — a
dark slab head with a pale eye-slit, neck, shoulders with resting arm tips,
a coat that flares into the void, stanced legs, boot line. Nihei register,
no face to read.

Reproduce any family: `python3 scripts/evolve-operative --frames 3 --seed N`.

---

## family `operative-v1` · seed 7

**frames**

```
     ▄▄████▄▄
    ██████████
    █▒▒▒▒▒▒▒▒█
    ▀████████▀
       ▐█▌
  ▐████████████▌
   ████████████
    ██████████
    ░███████░
   ░██████████░
  ░████████████░
    ██     ██
    ██     ██
    ██     ██
    ▀▀     ▀▀
```
`idle-0` · `[base]`

```
    ▄▄████▄▄
   ██████████
   █▒▒▒▒▒▒▒▒█
   ▀████████▀
      ▐█▌
   ████████████▌
  ▐████████████  ▌
    ██████████
    ░███████░
   ░██████████░
  ░████████████░
    ██     ██
    ██     ██
    ██     ██
    ▀▀     ▀▀
```
`idle-1` · `[arm-down, tilt-left]`

```
     ▄▄████▄▄
    ██████████
    ██████████
    ▀████████▀
  ▐    ▐█▌       ▌
   ████████████▌
  ██████████████
   ████████████
    ░███████░
   ░██████████░
  ░████████████░
    ██     ██
    ██     ██
    ██     ██
    ▀▀     ▀▀
```
`idle-2` · `[blink, arm-up, breath-in]`

**rationale** — Spans the full motion vocabulary in one family (weight-shift, blink, breath, coat flare, arm raise) while the silhouette stays slender and elegant. Reads as a clean four-beat loop: still → relax → inhale/blink → coat sway.

---

## family `operative-v1` · seed 42

**frames**

```
     ▄▄████▄▄
    ██████████
    █▒▒▒▒▒▒▒▒█
    ▀████████▀
       ▐█▌
  ▐████████████▌
   ████████████
    ██████████
    ░███████░
   ░██████████░
  ░████████████░
    ██     ██
    ██     ██
    ██     ██
    ▀▀     ▀▀
```
`idle-0` · `[base]`

```
     ▄▄████▄▄
    ██████████
    ██████████
    ▀████████▀
  ▐    ▐█▌       ▌
   ████████████▌
   ████████████
    ██████████
    ░███████░
   ░██████████░
  ░████████████░
     ██   ██
     ██   ██
     ██   ██
     ▀▀   ▀▀
```
`idle-1` · `[arm-up, blink, stance-narrow]`

```
     ▄▄████▄▄
    ██████████
    █▒▒▒▒▒▒▒▒█
    ▀████████▀
       ▐█▌
  ▐████████████▌
   ████████████
    ██████████
    ░███████░
   ░██████████░
  ░████████████░
   ██       ██
   ██       ██
   ██       ██
   ▀▀       ▀▀
```
`idle-2` · `[stance-wide]`

**rationale** — The cleanest-family runner-up. `idle-1` is a strong single-frame "operative holding still" for a static/still state; composition is tidy with no stray spacing.

---

## family `operative-v1` · seed 1337

**frames**

```
     ▄▄████▄▄
    ██████████
    █▒▒▒▒▒▒▒▒█
    ▀████████▀
       ▐█▌
  ▐████████████▌
   ████████████
    ██████████
    ░███████░
   ░██████████░
  ░████████████░
    ██     ██
    ██     ██
    ██     ██
    ▀▀     ▀▀
```
`idle-0` · `[base]`

```
     ▄▄████▄▄
    ██████████
    █▒▒▒▒▒▒▒▒█
    ▀████████▀
       ▐█▌
  ▐████████████▌
   ████████████
    ██████████
    ░███████░
  ░░██████████░░
 ░░████████████░░
    ██     ██
    ██     ██
    ██     ██
    ▀▀     ▀▀
```
`idle-1` · `[breath-in, coat-flare, breath-out]`

```
    ▄▄████▄▄
   ██████████
   █▒▒▒▒▒▒▒▒█
   ▀████████▀
      ▐█▌
   ████████████▌
  ▐████████████  ▌
    ██████████
    ░███████░
  ░░██████████░░
 ░░████████████░░
    ██     ██
    ██     ██
    ██     ██
    ▀▀     ▀▀
```
`idle-2` · `[arm-down, coat-flare, tilt-left]`

**rationale** — Coat-dominated family; the double flare is the strongest silhouette drama but recomposes the same hem with less limb variety.

---

## family `operative-v1` · seed 2049

**frames**

```
     ▄▄████▄▄
    ██████████
    █▒▒▒▒▒▒▒▒█
    ▀████████▀
       ▐█▌
  ▐████████████▌
   ████████████
    ██████████
    ░███████░
   ░██████████░
  ░████████████░
    ██     ██
    ██     ██
    ██     ██
    ▀▀     ▀▀
```
`idle-0` · `[base]`

```
     ▄▄████▄▄
    ██████████
    █▒▒▒▒▒▒▒▒█
    ▀████████▀
  ▐    ▐█▌       ▌
   ████████████▌
   ████████████
    ██████████
    ░███████░
   ░██████████░
  ░████████████░
     ██   ██
     ██   ██
     ██   ██
  ▖  ▀▀   ▀▀     ▗
```
`idle-1` · `[stance-narrow, arm-up, prop]`

```
    ▄▄████▄▄
   ██████████
   █▒▒▒▒▒▒▒▒█
   ▀████████▀
      ▐█▌
  ▐████████████▌
    ██████████
     ████████
    ░███████░
   ░██████████░
  ░████████████░
    ██     ██
    ██     ██
    ██     ██
    ▀▀     ▀▀
```
`idle-2` · `[breath-out, tilt-left]`

**rationale** — Standout prop work: the floor glint gives the operative a grounded, living surface to stand on, echoing the megastructure floor. The exhale frame is more dramatic than seed 1337's and keeps the upper silhouette simple.

---

## Current pick — seed 7

Adopt **family `operative-v1`, seed 7** (`--frames 4`). It is the only family
that carries the four required motion beats together and still reads as one
slender, elegant figure:

- `idle-0` steady base → `idle-1` relaxed weight-shift + head cant →
  `idle-2` **blink** (eye-slit closes) with arms raised and **breath-in** →
  `idle-3` **coat-flare** (coat sway).

That is a self-contained idle loop with blink, breath, and cloth motion — the
whole brief in one seed. Runner-up: **seed 42** if a single static
"operative" glyph is preferred (its `idle-1` is the stronger still pose); keep
**seed 2049**'s floor-glint prop in mind for a grounded variant.

Regenerate the adopted JSON for the TUI worker:

```
python3 scripts/evolve-operative --frames 4 --seed 7 --out operative-frames.json
```
