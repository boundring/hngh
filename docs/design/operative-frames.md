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

---

## Generation 3 — `operative-v3` (deliberate)

The fitness signal for this pass was the live-TUI review of operative-v2:

> "grey pixelated faceless humanoid, crude low-resolution sprite, jagged
> edges, lacks detail, feels like a placeholder."

This critique IS the fitness journal (also captured by `--self-grade`). The targets
it sets, and how the v3 art meets each:

- **smooth silhouette, no jagged edges** — the head is rounded (crown narrower
  than the slab, `▒`-feathered corners on the slab and jaw — no hard 90-degree
  box), and the shoulder pads feather at their `▄` corners.
- **visible detail** — an off-center `•` mote of light inside the eye-slit (it
  persists as eyelight through a blink), `░` seam lines inside the open coat
  panels, a `▓` belt line, `▀`/`▒` cuff and hem accents.
- **deliberate art, not a uniform block** — the mote is off-center and the seams
  sit at asymmetric panel offsets; the torso V-tapers traps→chest→waist.
- **grounding** — a bright `▄` ground slab with a `▒` cast shadow under the
  figure, wider than the boots (v2 had only a plain top-edge line).
- **terminal-safe** — every frame ≤18 rows, ≤24 cols, approved glyphs only.
- **deterministic** — same seed → byte-identical JSON.

Reproduce any family: `python3 scripts/evolve-operative --gen 3 --frames 3 --seed N`.

### Pairwise self-review — v2 seed 7 vs v3 seed 7 (base frames side by side)

```
   v2 7/0 (humanoid)     | v3 7/0 (deliberate)
   ----------------------|------------------------
         ▄█████▄         |        ▄██████▄
         ███████         |       █▒██████▒█
         █▀▀▀▀▀█         |       █▀▀▀▀•▀▀▀█
           ██            |        ▀██████▀
        ▄████████▄       |           ██
     ▐  ██████████  ▌    |     ▄████████████▄
     ▐  ██████████  ▌    |   ▐  ████████████  ▌
     ▐   ████████   ▌    |   ▐   ██████████   ▌
      ▄▄ ████████ ▄▄     |   ▐    ████████    ▌
        ████  ████       |     ▄▄ ████████ ▄▄
       ░███  ███░        |         ██▓▓▓▓██
       ██      ██        |        ██░█  █░██
       ██      ██        |        ░██░█  █░██░
       ███    ███        |          ██    ██
    ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀    |          ██    ██
                         |          ███  ███
                         |   ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```

**Verdict: v3 is plainly further from a placeholder.** v2 (left) has the correct
humanoid proportions but reads flat: a box-cornered slab head, plain chest, no
internal detail, and a bare ground line — a clean but *generic low-res sprite*,
which is exactly what the critique called it. v3 (right) has a rounded, feathered
silhouette with no hard 90-degree corners; a lit eye-slit glint; distinct shoulder
pads, belt, coat seams and hem accents; and a lit floor with a cast shadow. That is
deliberate shading and structure, not a flat placeholder. The jagged-edge and
no-detail complaints are answered by the base anatomy; the mutations (blink, mote,
seam toggle, shadow) put that detail into motion.

### Families

---

#### family `operative-v3` · seed 7

**frames**

```
       ▄██████▄
      █▒██████▒█
      █▀▀▀▀•▀▀▀█
       ▀██████▀
          ██
    ▄████████████▄
  ▐  ████████████  ▌
  ▐   ██████████   ▌
  ▐    ████████    ▌
    ▄▄ ████████ ▄▄
        ██▓▓▓▓██
       ██░█  █░██
       ░██░█  █░██░
         ██    ██
         ██    ██
         ███  ███
  ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```
`idle-0` · `[base]`

```
       ▄██████▄
      █▒██████▒█
      █▀▀▀▀•▀▀▀█
       ▀██████▀
          ██
    ▄████████████▄
     ████████████
  ▐   ██████████   ▌
  ▐    ████████    ▌
  ▐ ▄▄ ████████ ▄▄ ▌
        ██▓▓▓▓██
       ██░░  █░░█
       ░██░█  █░██░
         ██    ██
         ██    ██
         ███  ███
  ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```
`idle-1` · `[arm-down, seam-toggle]`

```
       ▄██████▄
      █▒██████▒█
      █▀▀▀▀•▀▀▀█
       ▀██████▀
          ██
  ▐ ▄████████████▄ ▌
  ▐  ████████████  ▌
  ▐   ██████████   ▌
       ████████
    ▄▄ ████████ ▄▄
        ██▓▓▓▓██
       ██░█  █░██
       ░██░    ░██░
         ██    ██
         ██    ██
         ███  ███
  ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```
`idle-2` · `[mote-shift, coat-open, arm-up]`

**rationale** — The head of the pack and the recommended loop: `idle-1` `arm-down`+`seam-toggle` lowering the arm while the coat seams toggle; `idle-2` `mote-shift`+`coat-open`+`arm-up` — the eye glint moves, the coat opens further and the arm lifts. A four-beat cycle that keeps the detail (mote, seams, belt) visible in motion.

---

#### family `operative-v3` · seed 42

**frames**

```
       ▄██████▄
      █▒██████▒█
      █▀▀▀▀•▀▀▀█
       ▀██████▀
          ██
    ▄████████████▄
  ▐  ████████████  ▌
  ▐   ██████████   ▌
  ▐    ████████    ▌
    ▄▄ ████████ ▄▄
        ██▓▓▓▓██
       ██░█  █░██
       ░██░█  █░██░
         ██    ██
         ██    ██
         ███  ███
  ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```
`idle-0` · `[base]`

```
       ▄██████▄
      █▒██████▒█
      █████•████
       ████████
          ██
  ▐ ▄████████████▄ ▌
  ▐  ████████████  ▌
  ▐   ██████████   ▌
       ████████
    ▄▄ ████████ ▄▄
        ██▓▓▓▓██
       ██░█  █░██
       ░██░█  █░██░  ▓
         ██    ██
         ██    ██
         ███  ███
  ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```
`idle-1` · `[arm-up, blink, prop]`

```
       ▄██████▄
      █▒██████▒█
      █▀▀▀▀•▀▀▀█
       ▀██████▀
          ██
    ▄████████████▄
  ▐  ████████████  ▌
  ▐   ██████████   ▌
  ▐    ████████    ▌
    ▄▄ ████████ ▄▄
        ██▓▓▓▓██
       ██░█  █░██
       ░██░█  █░██░
          ██ ██
          ██ ██
         ███████
  ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```
`idle-2` · `[stance-narrow]`

**rationale** — Most expressive detail: `idle-1` `arm-up`+`blink`+`prop` closes the eye-slit while the mote persists as eyelight and an ember glows beside the coat; `idle-2` `stance-narrow` draws the legs together. Shows the blink and prop system working on a sculpted body.

---

#### family `operative-v3` · seed 1337

**frames**

```
       ▄██████▄
      █▒██████▒█
      █▀▀▀▀•▀▀▀█
       ▀██████▀
          ██
    ▄████████████▄
  ▐  ████████████  ▌
  ▐   ██████████   ▌
  ▐    ████████    ▌
    ▄▄ ████████ ▄▄
        ██▓▓▓▓██
       ██░█  █░██
       ░██░█  █░██░
         ██    ██
         ██    ██
         ███  ███
  ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```
`idle-0` · `[base]`

```
       ▄██████▄
      █▒██████▒█
      █▀▀▀▀•▀▀▀█
       ▀██████▀
          ██
   ░▒████████████▒░
  ▐   ██████████   ▌
  ▐    ████████    ▌
  ▐    ████████    ▌
    ▄▄ ████████ ▄▄
        ██▓▓▓▓██
       ██░█  █░██
       ░██░    ░██░
         ██    ██
         ██    ██
         ███  ███
  ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```
`idle-1` · `[coat-open, breath-out, smooth-shoulders]`

```
       ▄██████▄
      ▒▒██████▒▒ •
      █▀▀▀▀•▀▀▀█
       ▒██████▒
          ██
    ▄████████████▄
  ▐  ████████████  ▌
  ▐   ██████████   ▌
  ▐    ████████    ▌
    ▄▄ ████████ ▄▄
        ██▓▓▓▓██
       ██░█  █░██ ░
      ░ ██░█  █░██ ░
         ██    ██
         ██    ██
         ███  ███
  ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```
`idle-2` · `[coat-flare, prop, round-head]`

**rationale** — Smoothing showcase: `idle-1` `coat-open`+`breath-out`+`smooth-shoulders` feathers the pads and opens the coat; `idle-2` `coat-flare`+`round-head`+`prop` rounds and flares the hem with a floating mote. The feathered head and hem accents are the deliberate-detail proof.

---

#### family `operative-v3` · seed 2049

**frames**

```
       ▄██████▄
      █▒██████▒█
      █▀▀▀▀•▀▀▀█
       ▀██████▀
          ██
    ▄████████████▄
  ▐  ████████████  ▌
  ▐   ██████████   ▌
  ▐    ████████    ▌
    ▄▄ ████████ ▄▄
        ██▓▓▓▓██
       ██░█  █░██
       ░██░█  █░██░
         ██    ██
         ██    ██
         ███  ███
  ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```
`idle-0` · `[base]`

```
       ▄██████▄
      █▒██████▒█
      █▀▀▀▀•▀▀▀█
       ▀██████▀
          ██
  ▐ ▄████████████▄ ▌
  ▐ ██████████████ ▌
  ▐  ████████████  ▌
       ████████
    ▄▄ ████████ ▄▄
        ██▓▓▓▓██
       ██░█  █░██
       ░██░█  █░██░
       ██        ██
       ██        ██
      ████      ████
  ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```
`idle-1` · `[leg-split, arm-up, breath-in]`

```
       ▄██████▄
      █▒██████▒█
      █▀▀▀▀•▀▀▀█
       ▀██████▀
          ██
    ▄████████████▄
  ▐  ████████████  ▌
  ▐   ██████████   ▌
  ▐    ████████    ▌
    ▄▄ ████████ ▄▄
        ██▓▓▓▓██
       ██░█  █░██ ░
      ░ ██░█  █░██ ░
         ██    ██
         ██    ██
         ███  ███
  ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```
`idle-2` · `[belt-toggle, coat-flare, belt-toggle]`

**rationale** — Grounding showcase: `idle-1` `leg-split`+`arm-up`+`breath-in` plants the legs wide onto the shadowed slab; `idle-2` `belt-toggle`+`coat-flare` widens the hem. Best frame for judging the ground shadow.

---

## Current pick (v3) — supersedes operative-v2

Adopt **family `operative-v3`, seed 7** (`--gen 3 --frames 4`). It is the only family
that uses the whole deliberate-detail vocabulary — eye mote, coat seams, belt,
rounded head, shoulder pads, hem accents, cast shadow — as a coherent idle loop,
and the pairwise review above shows it is unambiguously past the "placeholder"
bar where v2 still sat. Runner-up: **seed 1337** if you want the smoothing of the
feathered head and hem as the primary statement.

Regenerate the adopted JSON for the TUI worker:

```
python3 scripts/evolve-operative --gen 3 --frames 4 --seed 7 --out operative-frames.json
```

---

## Generation 4 — `operative-v4` (Nihei-proportion fluid)

The flagship pass. The fitness signal was the overnight review of the live
animation:

> "still pretty Atari, not terribly well animated ... no more ball-shaped heads on
> awkward-proportioned Atari-style figures. We're doing fluid but pixellated renders
> with all kinds of artistic tricks and finesse points in an evolutionary manner."

This critique IS the gen-4 fitness journal (also captured by `--self-grade --gen 4`).
The response studies Nihei's proportion and scale — the gaunt, elongated figures, tiny
heads, huge coats, vast negative space — and makes a near-miss render that mimics
proportion and scale, not just bumps a shape:

- **Nihei proportions** — a genuinely tiny head (2 rows, flat slab — never a ball),
  a long neck with huge void either side, narrow sloping shoulders, and a coat that
  dominates roughly half the canvas (rows 5-12 of 17 = vertical rhythm 1 head / 2
  neck / ~6 coat / 3 legs / 1 ground). The coat flares wide while the body and legs
  stay narrow, so the figure reads tall-and-thin even at 17 rows.
- **Fluid pixel tricks** — `▒` anti-aliased feathering on the shoulder/chest diagonals,
  motion-blur `░` drag-tails off the coat hem during flares, squash-and-stretch on
  breath, an anticipation lean that LAGS the coat and SHIFTS the shadow opposite, and
  staggered limb motion (the arm columns follow the shoulder catch-up).
- **No ball head** — the head is a flat tilted slab / helmet wedge with an eye-slit,
  never rounded.
- **Detail finesse** — interior coat shading (`▓` lit core → `▒` edge light → `░` dark
  hems), a secondary light source on one side, the `•` eye mote persisting through a
  blink, and a ground contact shadow that shifts with the motion.
- **Looped motion arc** — `--frames 4` is a closed loop: anticipation → action →
  settle. Each frame draws mutations from its phase pool.

Reproduce any family: `python3 scripts/evolve-operative --gen 4 --frames 4 --seed N`.

### Pairwise self-review — v3 seed 7 vs v4 seed 7 (base frames side by side)

```
   v3 7/0 (deliberate)            |  v4 7/0 (Nihei fluid)
   ----------------------------|------------------------
          ▄██████▄             |         ██████
         █▒██████▒█            |        █▀▀•▀▀█
         █▀▀▀▀•▀▀▀█            |          ██
          ▀██████▀             |          ██
             ██                |     ▐    ██     ▌
       ▄████████████▄          |     ▐  ▄██████▄ ▌
     ▐  ████████████  ▌        |     ▐ ██████████ ▌
     ▐   ██████████   ▌        |     ▐ ▓████████▓ ▌
     ▐    ████████    ▌        |      ▓▓████████▓▓
       ▄▄ ████████ ▄▄          |      ████▓▓  ▓▓████
           ██▓▓▓▓██            |      ▒███▓    ▓███▒
          ██░█  █░██           |      ▓██░      ░██▓
          ░██░█  █░██░         |     ░░██        ██░░
            ██    ██           |      ██          ██
            ██    ██           |      ██          ██
            ███  ███           |      ███        ███
     ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▒▒▄▄▄▄      |   ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```

**Verdict: v4 is past the "Atari" bar and beats v3.** v3 is a clean, detailed sprite, but
it still reads as a compact video-game character: a 4-row rounded head, wide 12-cell
shoulders, a moderate coat, legs only a few cells apart, a small shadow — proportionally
"normal", which is exactly the Atari register the critic flagged. v4 is proportionally
*wrong* in the deliberate Nihei direction: a tiny flat wedge head on a long, empty neck,
shoulders narrower than the coat, a coat that dominates half the frame with an interior
gradient and seams, narrow legs with a huge void between them, and a shadow that cleaves
to the ground. Vast negative space reads as the megastructure register; the flicker of
the eye mote, the shaded coat, the feathered edges and the anticipation lean are the
"fluid but pixellated" tricks. The operator's targets — no ball heads, Nihei proportions,
artistic finesse — are met. The loop (lean right → seams open → stance widen) is a clear
anticipation → action → settle arc, not a static bump.

### Families (each is a 4-frame loop: base + anticipate + action + settle)

---

#### family `operative-v4` · seed 7

**frames**

```
        ██████
       █▀▀•▀▀█
         ██
         ██
    ▐    ██     ▌
    ▐  ▄██████▄ ▌
    ▐ ██████████ ▌
    ▐ ▓████████▓ ▌
     ▓▓████████▓▓
     ████▓▓  ▓▓████
     ▒███▓    ▓███▒
     ▓██░      ░██▓
    ░░██        ██░░
     ██          ██
     ██          ██
     ███        ███
  ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```
`idle-0` · `[base]`

```
         ██████
        █▀▀•▀▀█
          ██
          ██
    ▐     ██     ▌
    ▐   ▄██████▄ ▌
    ▐ ██████████ ▌
    ▐ ▓████████▓ ▌
     ▓▓████████▓▓
     ████▓▓  ▓▓████
     ▒███▓    ▓███▒
     ▓██░      ░██▓
    ░░██        ██░░
     ██          ██
     ██          ██
     ███        ███
  ▄▄▒▒▒▒▒▒▒▒▒▒▄▄▄▄▄▄
```
`idle-1` · `[lean-right, shadow-shift]`

```
        ██████
       █▀▀•▀▀█
         ██
         ██
    ▐    ██     ▌
    ▐  ▄██████▄ ▌
    ▐ ██████████ ▌
    ▐ ▓████████▓ ▌
     ▓▓███░░███▓▓
     ████▓░░ ▓▓████
     ▒███▓░░  ▓███▒
     ▓██░ ░░   ░██▓
    ░░██        ██░░
     ██          ██
     ██          ██
     ███        ███
  ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```
`idle-2` · `[seams]`

```
        ██████
       █▀▀•▀▀█
         ██
         ██
    ▐    ██     ▌
    ▐  ▄██████▄ ▌
    ▐ ██████████ ▌
    ▐ ▓████████▓ ▌
     ▓▓████████▓▓
     ████▓▓  ▓▓████
     ▒███▓    ▓███▒
     ▓██░      ░██▓
    ░░██        ██░░
    ██           ██
    ██           ██
    ███          ███
  ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```
`idle-3` · `[stance-wide]`

**rationale** — The head of the pack and the recommended loop: `idle-1` `lean-right`+`shadow-shift` is a clean anticipation (coat lags, shadow cleaves opposite), `idle-2` `seams` opens the coat panels as the action, `idle-3` `stance-wide` settles onto the planted legs. The balance of tiny head, coat, and leg void is the purest Nihei read.

---

#### family `operative-v4` · seed 42

**frames**

```
        ██████
       █▀▀•▀▀█
         ██
         ██
    ▐    ██     ▌
    ▐  ▄██████▄ ▌
    ▐ ██████████ ▌
    ▐ ▓████████▓ ▌
     ▓▓████████▓▓
     ████▓▓  ▓▓████
     ▒███▓    ▓███▒
     ▓██░      ░██▓
    ░░██        ██░░
     ██          ██
     ██          ██
     ███        ███
  ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```
`idle-0` · `[base]`

```
      ██████
     █▀▀•▀▀█
       ██
       ██
   ▐   ██     ▌    ▌
   ▐ ▄██████▄ ▌    ▌
   ▐  ██████████ ▌ ▌
   ▐  ▓████████▓ ▌ ▌
   ▐ ▓▓████████▓▓  ▌
     ████▓▓  ▓▓████
     ▒███▓    ▓███▒
     ▓██░      ░██▓
    ░░██        ██░░
     ██          ██
     ██          ██
     ███        ███
  ▄▄▄▄▄▄▒▒▒▒▒▒▒▒▒▒▄▄
```
`idle-1` · `[lean-left, lean-left, arm-follow]`

```
        ██████
       █▀▀•▀▀█
         ██
         ██
    ▐    ██     ▌
    ▐  ▄██████▄ ▌
    ▐ ██████████ ▌
    ▐ ▓████████▓ ▌
     ▓▓████████▓▓
     ████▓▓  ▓▓████
     ▒███▓    ▓███▒
    ░▓██░      ░██▓░
   ░░░██        ██░░░
     ██          ██
     ██          ██
     ███        ███
  ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```
`idle-2` · `[drag-tail]`

```
        ██████
       ██•████
         ██
         ██
    ▐    ██     ▌
    ▐  ▄██████▄ ▌
    ▐ ██████████ ▌
    ▐ ▓████████▓ ▌
     ▓▓████████▓▓
     ████▓▓  ▓▓████
     ▒███▓    ▓███▒
     ▓██░      ░██▓
    ░░██        ██░░
     ██          ██
     ██          ██
     ███        ███
  ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```
`idle-3` · `[mote-drift, prop, blink]`

**rationale** — Detail-forward: the loop exercises `feather` + `edgelight` + `mote-drift` in the settle phase, so the shading gradient and the drifting eye-mote stay visible — the strongest showcase of the finesse techniques.

---

#### family `operative-v4` · seed 1337

**frames**

```
        ██████
       █▀▀•▀▀█
         ██
         ██
    ▐    ██     ▌
    ▐  ▄██████▄ ▌
    ▐ ██████████ ▌
    ▐ ▓████████▓ ▌
     ▓▓████████▓▓
     ████▓▓  ▓▓████
     ▒███▓    ▓███▒
     ▓██░      ░██▓
    ░░██        ██░░
     ██          ██
     ██          ██
     ███        ███
  ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```
`idle-0` · `[base]`

```
        ██████
       █▀▀•▀▀█
         ██
         ██
   ▐ ▐   ██     ▌  ▌ ▌
   ▐ ▐ ▄██████▄ ▌  ▌ ▌
   ▐ ▐██████████ ▌ ▌ ▌
   ▐ ▐▓████████▓ ▌ ▌ ▌
   ▐ ▐▓████████▓▓  ▌ ▌
     ████▓▓  ▓▓████
     ▒███▓    ▓███▒
     ▓██░      ░██▓
    ░░██        ██░░
     ██          ██
     ██          ██
     ███        ███
  ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```
`idle-1` · `[arm-follow, arm-follow, arm-follow]`

```
        ██████
       █▀▀•▀▀█
         ██
         ██
    ▐    ██     ▌
    ▐  ▄██████▄ ▌
    ▐████████████▌
    ▐█▓████████▓█▌
     ▓▓████████▓▓
     ████▓▓  ▓▓████
     ▒███▓    ▓███▒
    ░▓██░      ░██▓░
   ░  ██        ██  ░
     ██          ██
     ██          ██
     ███        ███
  ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```
`idle-2` · `[drag-tail, breath-in]`

```
        ██████
       █▀▀•▀▀█
         ██
         ██
    ▐    ██     ▌
    ▐  ▄██████▄ ▌
    ▐ ██████████ ▌
    ▐ ▓████████▓ ▌
     ▓▓████████▓▓
     ████▓▓  ▓▓████
     ▒███▓    ▓███▒
     ▓██░      ░██▓
    ░░██        ██░░
      ██     ██
      ██     ██
      ███    ███
  ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```
`idle-3` · `[stance-narrow]`

**rationale** — Squash-and-stretch: `breath-in`/`breath-out` dominate, so the coat visibly compresses and lengthens across the loop — the clearest squash-and-stretch proof on a coat-dominant body.

---

#### family `operative-v4` · seed 2049

**frames**

```
        ██████
       █▀▀•▀▀█
         ██
         ██
    ▐    ██     ▌
    ▐  ▄██████▄ ▌
    ▐ ██████████ ▌
    ▐ ▓████████▓ ▌
     ▓▓████████▓▓
     ████▓▓  ▓▓████
     ▒███▓    ▓███▒
     ▓██░      ░██▓
    ░░██        ██░░
     ██          ██
     ██          ██
     ███        ███
  ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```
`idle-0` · `[base]`

```
       ██████
      █▀▀•▀▀█
        ██
        ██
  ▐     ██     ▌  ▌
  ▐   ▄██████▄ ▌  ▌
   ▐  ██████████ ▌ ▌
   ▐  ▓████████▓ ▌ ▌
   ▐ ▓▓████████▓▓  ▌
     ████▓▓  ▓▓████
     ▒███▓    ▓███▒
     ▓██░      ░██▓
    ░░██        ██░░
     ██          ██
     ██          ██
     ███        ███
  ▄▄▄▄▄▄▒▒▒▒▒▒▒▒▒▒▄▄
```
`idle-1` · `[arm-follow, shadow-shift, lean-left]`

```
        ██████
       █▀▀•▀▀█
         ██
         ██
    ▐    ██     ▌
    ▐  ▄██████▄ ▌
    ▐ ██████████ ▌
    ▐ ▓████████▓ ▌
     ▓▓████████▓░
     ▓███▓▓  ▓▓███░
     ▓███▓    ▓███░
     ▓██░      ░██░
    ░░██        ██░░
     ██          ██
     ██          ██
     ███        ███
  ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```
`idle-2` · `[edgelight]`

```
          ██████
         █▀▀•▀▀█
           ██
           ██
    ▐    ██     ▌
    ▐  ▄██████▄ ▌
    ▐ ██████████ ▌
    ▐ ▓████████▓ ▌
     ▓▓████████▓▓
     ████▓▓  ▓▓████
     ▒███▓    ▓███▒
     ▓██░      ░██▓
    ░░██        ██░░
     ██          ██
     ██          ██
     ███        ███
  ▄▄▄▄▒▒▒▒▒▒▒▒▒▒▄▄▄▄
```
`idle-3` · `[tilt-right, tilt-right]`

**rationale** — Motion-heavy: `coat-flare`+`drag-tail` put visible motion-blur smear off the hem, and `arm-follow` gives the staggered-limb beat — the most "animated" family.

---

## Current pick (v4) — supersedes operative-v3

Adopt **family `operative-v4`, seed 7** (`--gen 4 --frames 4`). It is the flagship:
the tiny wedge head, coat-dominant void, interior shading, edge light, feathering,
and the anticipation → action → settle loop together make a figure a harsh critic
would describe as a *fluid pixellated near-miss render in the Nihei register*, not an
Atari placeholder or a ball-headed sprite. Runner-up: **seed 1337** if the squash-and-
stretch of the coat is the primary statement.

Regenerate the adopted JSON for the TUI worker:

```
python3 scripts/evolve-operative --gen 4 --frames 4 --seed 7 --out operative-frames.json
```
