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

---

## Generation 2 — `operative-v2` (humanoid)

Bred by `scripts/evolve-operative --gen 2`. The fitness signal from the v1
pick — *"reads as a distorted barcode"* — drove a full anatomy rework: the v1
slab (head nearly as wide as the body, 1-cell nub neck, arms as corner-tip
glyphs, uniform 10-wide torso column, matching legs) reads as one vertical
bar. v2 fixes the proportions that sell "human" at a glance:

- **head ≪ shoulders** — 3-row, 7-wide head under 10-wide shoulders/traps;
  `head-small` drops it to a 2-row head lifted to the canvas top (no void).
- **visible neck** — a 2-wide neck with void on both sides; `neck-gap` floats
  the head free of the shoulders.
- **arms as limbs, not column edges** — thin `▐`/`▌` arms hang at the canvas
  edges with a real negative-space gap to the torso; `arm-bend` (elbow) swings
  the forearms to hang under the upper arm.
- **V-taper torso** — shoulders (10w) narrow to a waist (8w), so the body is
  not a block.
- **open coat** — the coat is two panels with a center gap; `coat-open` widens
  the gap, `coat-flare` bells the hem.
- **legs apart** — two 2-wide legs with a 5–6 column gap; `stance-*`/`leg-split`
  widen or narrow it. Boots are wider than the shins; a ground slab anchors
  the figure.

New mutation vocabulary (v2): `neck-gap`, `arm-bend`, `leg-split`, `head-small`,
`coat-open`, plus carried `blink`, `tilt`, `breath-in/out`, `coat-flare`,
`arm-up/down`, `stance-*`, `prop`. Same determinism contract — the only entropy
is `random.Random(seed)`, so `--gen 2 --seed N` is byte-identical every run.

Reproduce any family: `python3 scripts/evolve-operative --gen 2 --frames 3 --seed N`.

---

### family `operative-v2` · seed 7

**frames**

```
      ▄█████▄
      ███████
      █▀▀▀▀▀█
        ██
     ▄████████▄
  ▐  ██████████  ▌
  ▐  ██████████  ▌
  ▐   ████████   ▌
   ▄▄ ████████ ▄▄
     ████  ████
    ░███  ███░
    ██      ██
    ██      ██
    ███    ███
 ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
```
`idle-0` · `[base]`

```
       ▄█████▄
       ███████
       █▀▀▀▀▀█
         ██
     ▄████████▄
  ▐  ██████████  ▌
  ▐  ██████████  ▌
  ▐   ████████   ▌
  ▄▄  ████████  ▄▄
     ████  ████
    ░███  ███░
    ██      ██
    ██      ██
    ███    ███
 ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
```
`idle-1` · `[arm-bend, tilt-right]`

```
      ▄█████▄
      ███████
      █▀▀▀▀▀█

     ▄████████▄
     ██████████
  ▐  ██████████  ▌
  ▐   ████████   ▌
  ▐▄▄ ████████ ▄▄▌
     ████  ████
    ░███  ███░
    ██      ██
    ██      ██
    ███    ███
 ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
```
`idle-2` · `[neck-gap, arm-up, arm-down]`

**humanoid rationale** — The head of the v2 pack and the recommended idle loop: `idle-1` `arm-bend`+`tilt-right` shows the elbow (forearms hang straight) with a head cant; `idle-2`/`idle-3` lift the head off the neck (`neck-gap`) and narrow the stance — a full four-beat cycle of a standing figure, never a column.

---

### family `operative-v2` · seed 42

**frames**

```
      ▄█████▄
      ███████
      █▀▀▀▀▀█
        ██
     ▄████████▄
  ▐  ██████████  ▌
  ▐  ██████████  ▌
  ▐   ████████   ▌
   ▄▄ ████████ ▄▄
     ████  ████
    ░███  ███░
    ██      ██
    ██      ██
    ███    ███
 ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
```
`idle-0` · `[base]`

```
      ███████
      ███████

        ██
     ▄████████▄
     ██████████
  ▐  ██████████  ▌
  ▐   ████████   ▌
  ▐▄▄ ████████ ▄▄▌
     ████  ████
    ░███  ███░
    ██      ██
    ██      ██
    ███    ███
 ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
```
`idle-1` · `[arm-down, blink, head-small]`

```
      ▄█████▄
      ███████
      █▀▀▀▀▀█
        ██
     ▄████████▄
  ▐  ██████████  ▌
  ▐  ██████████  ▌
  ▐   ████████   ▌
   ▄▄ ████████ ▄▄
     ████  ████
    ░███  ███░
   ██        ██
   ██        ██
  ███       ███
 ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
```
`idle-2` · `[leg-split]`

**humanoid rationale** — Smallest-head variant: `idle-1` is `arm-down`+`blink`+`head-small` — a 2-row head on broad shoulders, the most "compact humanoid" in the set; `idle-2` `leg-split` widens the stance into a confident planted pose.

---

### family `operative-v2` · seed 1337

**frames**

```
      ▄█████▄
      ███████
      █▀▀▀▀▀█
        ██
     ▄████████▄
  ▐  ██████████  ▌
  ▐  ██████████  ▌
  ▐   ████████   ▌
   ▄▄ ████████ ▄▄
     ████  ████
    ░███  ███░
    ██      ██
    ██      ██
    ███    ███
 ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
```
`idle-0` · `[base]`

```
     ▄█████▄
     ███████
     █▀▀▀▀▀█
       ██
     ▄████████▄
  ▐  ██████████  ▌
  ▐  ██████████  ▌
  ▐   ████████   ▌
   ▄▄ ████████ ▄▄
    ░█████ █████░
   ░█████ █████░
   ██        ██
   ██        ██
  ███       ███
 ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
```
`idle-1` · `[tilt-left, stance-wide, coat-flare]`

```
     ▄█████▄
     ███████
     █▀▀▀▀▀█
       ██
     ▄████████▄
  ▐  ██████████  ▌
  ▐  ██████████  ▌
  ▐   ████████   ▌
   ▄▄ ████████ ▄▄
    ████    ████
   ████    ████
    ██      ██
    ██      ██
    ███    ███
 ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
```
`idle-2` · `[tilt-left, coat-open]`

**humanoid rationale** — Coat-forward: `idle-1` `tilt`+`stance-wide`+`coat-flare` opens and bells the coat panels while the legs plant wide; `idle-2` `coat-open` widens the front gap — the most dramatic drapery, still a clear figure.

---

### family `operative-v2` · seed 2049

**frames**

```
      ▄█████▄
      ███████
      █▀▀▀▀▀█
        ██
     ▄████████▄
  ▐  ██████████  ▌
  ▐  ██████████  ▌
  ▐   ████████   ▌
   ▄▄ ████████ ▄▄
     ████  ████
    ░███  ███░
    ██      ██
    ██      ██
    ███    ███
 ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
```
`idle-0` · `[base]`

```
      ███████
      █▀▀▀▀▀█

        ██
     ▄████████▄
    ████████████
  ▐ ████████████ ▌
  ▐   ████████   ▌
  ▐▄▄ ████████ ▄▄▌
     ████  ████
    ░███  ███░
    ██      ██
    ██      ██
    ███    ███
 ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
```
`idle-1` · `[head-small, arm-down, breath-in]`

```
      ▄█████▄
      ███████
      ███████
        ██
     ▄████████▄
    ████████████
  ▐ ████████████ ▌
  ▐   ████████   ▌
  ▐▄▄ ████████ ▄▄▌
     ████  ████
    ░███  ███░
    ██      ██
    ██      ██
    ███    ███
 ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
```
`idle-2` · `[breath-in, blink, arm-down]`

**humanoid rationale** — Relaxed and prop-lit: `idle-1` `head-small`+`arm-down`+`breath-in` broadens the chest; `idle-2` `blink` with closed eye-slit reads as a downcast, still operative.

---

## Current pick (v2) — supersedes seed 7's v1

Adopt **family `operative-v2`, seed 7** (`--gen 2 --frames 4`). It beats the v1
pick on the exact fitness signal: the v2 figure reads as a human at a glance —
small head, visible neck, arms with negative space and a bent elbow, V-tapered
torso, open coat, separated legs, grounded boots — where v1's seed-7 `idle-0` is
still a blocky column a vision model would call a barcode.

Pairwise verdict (v2 vs v1 seed-7 `idle-0`, inspected side by side):

- v1: 4-row head ≈ shoulder width; 1-cell nub neck; arms are corner-tip glyphs on
  the shoulder row; uniform solid torso; matching solid legs — one vertical bar.
- v2: head 7w under 10w shoulders; 2-cell neck void; thin arms at the canvas edges
  with a clear arm/torso gap and an elbow; shoulders→waist V-taper; two open coat
  panels; 2-wide legs with a 5–6 col gap; wider boots; ground slab.

v2 is **plainly more humanoid** — the barcode critique is answered.

Regenerate the adopted JSON for the TUI worker:

```
python3 scripts/evolve-operative --gen 2 --frames 4 --seed 7 --out operative-frames.json
```
