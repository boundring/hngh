# Publication review 01 -- gag manga + daily dispatch

Date: 2026-09-12. Subject: the existing sample manga
(`docs/media/manga/sample-draft.json`, `sample-panel.svg`, `sample-panel.png`)
and the current public dispatch edition
(`docs/dispatch/2026-09-12.md`, latest committed). Protocol: the two-pass
supportive/adversarial pattern from the research review transition
(automation/cadence/hour/33-research-beat.sh, REVIEW=1). The digest
md/html renderers are owned by a sibling worker tonight: this review
reads the committed edition as-is and records the delta, it does not
edit it.

Verdict up front: the discipline layer is working and worth keeping;
the art and comedy layers are skeletons. The panel is a caption
bubble floating in whitespace, the dialogue is structurally correct
but comedically inert, and the strip has no cast and no arc. Actions
1-3 below are landed in this same pass; action 4 is the standing
cadence (automation/cadence/day/26-publication-review.sh +
jobs/publication-review.py).

## Supportive pass (what works against the bar)

1. **The attribution footer is the discipline working.**
   `[DRAMATIZATION - procedural gag, not a real quote] -- GDELT 2.0
   export, <url>` keeps fact and symbol separated exactly per the
   display-register law: the gag never enters a record, the source
   never hides behind the joke.

2. **The grounded-facts strip.** "Grounded event: ... (severity
   NOTABLE). Source cited below." anchors the gag to a real GDELT row
   before the joke is allowed to exist. Evidence-first, one caption per
   state -- the Saga voice, transplanted to a panel.

3. **SFX "KRAK" exists and sits apart.** Rotated, lower-left, clear of
   the bubble tail: the one element that reads like a comic instead of
   a form. (The adversarial pass disputes its exact anchor; that it is
   there at all is right.)

4. **The deterministic banks: comedy from procedure.** The panel is
   reproducible from a GDELT headline with zero judgment calls at
   render time (manga-draft.py, seed = headline bytes). That is the
   right P0 shape: the machine can publish a gag strip every day it has
   news, and the same item always drafts the same panel.

5. **The dispatch's Deck structure + feed citations.** Deck A (outside
   world) / Deck B (megastructure), every section carrying its
   `_sources:` line and every narrative paragraph a `<!-- feeds: ... -->`
   citation. The newspaper knows where its facts come from, hour by
   hour, including honest quiet windows ("none ? quiet window").

## Adversarial pass (what fails against the bar)

1. **[severity: high] The panel is 60% empty.** The optional image was
   omitted when the ComfyUI leg (port 8188, probed 2026-09-12: DOWN)
   could not serve it. What shipped is a caption-bubble skeleton
   without its art: caption box, one speech bubble, one SFX word,
   nothing happening. A gag panel with no gag drawn is a proof, not a
   strip.

2. **[severity: high] No character presence.** The cast roster is
   empty: nothing recurs, nobody has a face, so nothing can be funny
   twice. Gag manga lives on recurring characters (and the display
   register already owns the silhouette: gaunt, small head, dark coat,
   Nihei register) -- the pipeline never renders a single one.

3. **[severity: medium] Procedural dialogue is comedically inert.**
   The template banks produce flat lines: "We prepared for everything
   except this exact thing." is structurally correct (deadpan,
   evidence-adjacent) but inert because it is aimed at nothing -- no
   scene linkage, no character speaking it, no setup before the line.

4. **[severity: medium] The layout wastes 40% vertical.** The art zone
   is 560px of an 820px panel and the empty strip eats the rest; with
   no image the void is unmasked. The bubble floats mid-right with no
   third-point anchor, the SFX sits wherever it was first put.

5. **[severity: low] SFX placement is arbitrary.** "KRAK" has no
   relationship to the action (there is no action) and its anchor is
   hand-set in the skeleton, not derived from the scene pick.

6. **[severity: medium] Deck A lacks the summary/quip layer.** Every
   Deck A item is a raw headline + URL; there is no one-line summary or
   quip above the fold. Delta note: a sibling worker owns the
   digest-html/public renderer overhaul tonight; this review reads the
   md edition as committed (docs/dispatch/2026-09-12.md) and flags the
   layer's absence, it does not edit their surface.

7. **[severity: low] No serialized continuity.** One-off panels keyed
   to random headlines: a gag strip needs an arc (recurring bits, a
   running joke, callbacks). The bestiary/Saga register is already
   building one on the dispatch side; the manga side serializes nothing.

## Improvement actions and dispositions

### 1. Art -- style-row refinement + regenerate (landed: prompt; leg-gated: render)

The manga-panel row in `automation/config/imagegen-styles.tsv` now
carries: two-to-three recurring character silhouettes (small heads,
gaunt coats, thumbnail-readable), panel-dynamic composition (diagonal
depth, one focal action), and dense cross-hatching on towering dark
structures and shadow -- plus vast background negative space so bubbles
get room. (Register intent is the Nihei book, per the display register;
the prompt itself carries pure descriptor language -- no artist names,
per the imagegen contract.)
Disposition: **prompt landed this pass**; the sample re-render is
**leg-gated** -- ComfyUI on 127.0.0.1:8188 was probed once and down,
so the next `automation/jobs/imagegen-submit.sh --style manga-panel`
run after the leg is up re-illustrates the sample. Until then the SVG
render (below) is the visible artifact.

### 2. Comedy banks -- cameo-keyed pools (landed this pass)

`automation/jobs/manga-draft.py` banks are now keyed by CAMEO class
(bureaucrat / engineer / nightwatch -- the night watch already exists
in the Saga register): per-class scene pools and deadpan quip pools,
cross-referenced so scene, dialogue, and SFX draw on different seed
divisors and a recurring character still varies. Register: dry,
deadpan, evidence-adjacent -- the Saga voice. The plan dict now carries
the `cameo` field, and `QUIP_BUDGET` (96 chars) is the deterministic
cap the cadence review checks. Disposition: **landed**.

### 3. Layout -- tighter panel skeleton (landed this pass)

`automation/config/manga-panel.svg`: the art zone grows 560 -> 640px
(~80% of panel height), the narrative strip shrinks to match, the
speech bubble is anchored at the upper-right third point of the art
zone (cx 682, cy 227) with its tail aimed into the composition, and the
SFX anchor moved to the lower-left third point. Text coordinates in
`render_svg` updated to match. Disposition: **landed**; the standing
cadence re-checks the ratio every day.

### 4. The standing cadence (landed this pass)

`automation/cadence/day/26-publication-review.sh` ->
`automation/jobs/publication-review.py`: every UTC day the latest manga
draft and the latest dispatch get the two-pass review. P0 stays
deterministic: the two passes are structured checklists derived from
this review doc (art present? bubble text within bounds? attribution
footer intact? quip budget respected? Deck A variety vs quiet-window
honesty?). A model-pass commentary runs ONLY when a cheap leg is idle;
its absence never fails the beat. Findings file:
`automation/digest/PUBLICATION-REVIEW-<date>.md` (supportive +
adversarial sections), report-queue rows for red findings, and
persistent issues escalate through the existing blocker ledger at scope
`publication:<artifact>` (same-cause attempts park after the shared
cooldown). Tests: `automation/tests/test-publication-review.sh`
(hermetic: a good draft passes; an empty/missing panel fails naming
the artifact; a quip-budget overage is flagged). Wired into the
automation Makefile test target.

## Cyclical wiring details

- Cadence: day tier, `automation/cadence/day/26-publication-review.sh`,
  fail-closed (every expected path exits 0; red becomes an alert row,
  never a dropped signal).
- Checker contract (jobs/publication-review.py, stdlib only): reads the
  latest `*-draft.json` under docs/media/manga/ plus its rendered SVG
  when present, and the latest docs/dispatch/<date>.md. Supportive
  checks: attribution footer intact, grounded-facts strip present,
  caption present, SFX present, quiet-window honesty (a "- none ?
  quiet window" section carries zero items). Adversarial checks: panel
  art present (fail names the artifact), art-zone ratio >= 0.7, bubble
  text within bounds, quip budget, cameo presence, Deck A quip-layer
  presence (delta-tracked while the sibling overhaul lands).
- Escalation: blocker ledger scope `publication:manga` /
  `publication:dispatch`; same cause twice -> parked + alert, success
  clears, parked rows auto-unpark on the shared cooldown.

## Verdict

Keep the discipline, feed the art. The next review cycle should be
able to see: a cast (cameo class named in every draft), a panel where
the art zone is not empty when the leg is up, and a Deck A with a
quip layer. Everything else -- the attribution footer, the grounded
strip, the deterministic reproducibility -- is the machine's taste and
should not move.
