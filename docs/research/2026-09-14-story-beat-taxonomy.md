# Which story-beat taxonomy (save-the-cat beats, Haruhi-style scene beats, or comic-specific action-beat/reaction-beat pairs) should annotate manga-draft.py's beat structure, and how does each beat class map to narrative_mode (image-only/dialogue-only/mixed) ratios measured by jobs/manga-vision.py?

Status: crystallized 2026-09-14 from research line `story-beat-taxonomy`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-story-beat-taxonomy.md.

# Line Contraction Record — Beat Taxonomy ↔ `narrative_mode`

**Line:** story-beat taxonomy for `manga-draft.py` and its mapping to `narrative_mode` ratios from `jobs/manga-vision.py`
**State:** contracting → contracted (this record is the lasting summary; update `research-lines.tsv` accordingly)
**Basis:** prior research beat of 2026-09-14 (expanding phase, truncated mid-protocol) plus this transition's consolidation

**Verification caveat (read first):** this transition could not open repository files directly. Claims below are grounded in the line's own record — which names `manga-draft.py`, `jobs/manga-vision.py`, and `research-lines.tsv` as real artifacts — but their internals are *not* independently re-verified here. External taxonomy claims (Save the Cat, Haruhi-style beats) cannot be verified from this repository and are flagged as such. Where the prior beat asserted craft-based expectations as if measured, this record downgrades them to hypotheses.

## Findings

**F1 — Granularity mismatch disqualifies the prose/screenplay taxonomies as the primary layer.** Save the Cat's beat set (macro-structural, feature-length screenplay scale) and Haruhi-style scene beats (scene-scale abstraction) both operate above the annotation target. The beat structure in `manga-draft.py` resolves at panel/beat granularity, where each unit must take exactly one `narrative_mode` value measured by `jobs/manga-vision.py`. Neither taxonomy decomposes to that level without an unmeasured intermediate translation layer. *(Save the Cat properties are standard screenwriting knowledge — Blake Snyder, *Save the Cat!* — not verifiable in-repo. "Haruhi-style scene beats" cannot be verified at all; see Thread T3.)*

**F2 — Action/reaction pairs share an axis with `narrative_mode`.** Comic action-beat/reaction-beat pairs are defined by panel-level visual function — *showing* vs. *saying/registering* — which is the same image/text axis that `narrative_mode` (image-only / dialogue-only / mixed) measures. It is the only candidate taxonomy that maps without inventing a bridge layer.

**F3 — The mapping is a falsifiable hypothesis, not a measured result.** The prior beat's table (below) is craft-based priors. The measurement protocol it sketched — annotate beats, run `jobs/manga-vision.py`, compare per-class mode ratios — was cut off before any numbers existed. This record deliberately does not launder those priors into findings.

| Beat class | Expected `narrative_mode` prior | Status |
|---|---|---|
| setup | image-only dominant | hypothesis, unmeasured |
| action | image-only dominant | hypothesis, unmeasured |
| reaction (internal) | image-only | hypothesis, unmeasured |
| reaction (externalized) | dialogue-only or mixed | hypothesis, unmeasured |
| impact/punchline | mixed dominant | hypothesis, unmeasured |

**F4 — Reaction is the polymorphic class.** It is the only class spanning all three modes, and the prior material resolved this only implicitly. It requires an explicit sub-annotation (internal vs. externalized) for the mapping to be deterministic.

## Recommendations

**R1.** Adopt a closed four-class comic-specific vocabulary for `manga-draft.py` beat annotations: `setup`, `action`, `reaction`, `impact`, with `reaction` carrying an `internal|externalized` sub-tag.

**R2.** Do not couple Save the Cat or Haruhi-style beats to `narrative_mode` at any level. If either is ever wanted, confine it to an optional outer (chapter/arc) layer, and keep that layer out of the mode-ratio pipeline.

**R3.** Encode the F3 table as expected-ratio priors per class, and use `jobs/manga-vision.py` output as the falsifier: a class whose measured distribution diverges sharply from its prior indicates either mislabeled beats or a taxonomy defect. This makes the taxonomy answerable to the repository's own instrument rather than to craft folklore.

**R4.** Record in `research-lines.tsv` that this line contracts with its central mapping unvalidated — the successor thread (T1) inherits a hypothesis, not a result.

## Open threads (spawn candidates)

- **T1 — Measurement run:** produce the per-beat-class `narrative_mode` ratio table from `jobs/manga-vision.py` over actual drafts; accept or revise the F3 priors.
-

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
