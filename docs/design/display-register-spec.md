# Display register

Status: DESIGN — slow-tier register consolidation, Task D, 2026-08-27.

Source: `assistant-interface.md`, `operative-frames.md` (Generation 4, the
measured-constants pass), `presentation-boundary.md`, `reference-lexicon-policy.md`,
`buddy-menu-spec.md`, `gamified-runs.md`, `interface-grading.md`, `../intent.md`,
`../research/2026-08-11-clean-architecture-roguelike-run-review.md` ("docs/aesthetic.md"
bullets), `../../scripts/grade-interface`.

Cross-links: `assistant-interface.md`, `buddy-menu-spec.md`, `gamified-runs.md`,
`presentation-boundary.md`, `reference-lexicon-policy.md`, `interface-grading.md`,
`autonomous-development-control.md`.

## 1. Register

Every operator-facing surface in Hngh speaks one register: a Nihei book — a
slender, faceless figure in a dark coat with only a pale eye-slit for a face,
speech arriving like a caption in the margin, standing in the quiet of a
megastructure ([assistant-interface.md](assistant-interface.md)). The register
is quiet, evidence-first, and honest: the literal fact renders first, and
flavor is optional perceptual decoration that never changes a fact, never
enters a record, and never demands attention. Stillness is the default;
motion is information.

## 2. Voice and captions

- One or two sentences, state-driven, never chatter — the operative speaks
  in evidence: "The queue holds its breath." One caption per state snapshot
  ([assistant-interface.md](assistant-interface.md)). `alert` and `victory` are event-driven
  single transitions that play once and settle; captions never repeat on
  later ticks, so the operative cannot nag
  ([buddy-menu-spec.md](buddy-menu-spec.md), [gamified-runs.md](gamified-runs.md)).
- Sentence case only; ALL-CAPS is reserved for literal protocol terms and
  state tokens as recorded — no shout lines.
- Plain voice ([../intent.md](../intent.md)): short declarative sentences,
  concrete nouns — "The run ends in one of a few definite ways." Domain
  keywords (`rotation`, `candidate`, `certificate`, `heartbeat`, `wake`)
  carry the color and may later grow hover definitions
  ([assistant-interface.md](assistant-interface.md)).
- Forbidden shapes: nagging loops; uninvited interruption of a running
  surface (the buddy is summoned, never summoning); first-person fiction
  about events that did not happen; the literal fact masked as a metaphor;
  wording implying affiliation, endorsement, or hidden capability
  ([presentation-boundary.md](presentation-boundary.md)); an invented event
  for an unmapped state — unmapped terminal states render their literal term
  ([gamified-runs.md](gamified-runs.md)).

## 3. Composition and scale

Generation-4 measurements, cited as measured constants from the v4 fitness
pass ([operative-frames.md](operative-frames.md)); reusable ratios, not one
figure's pixels:

- Head = 2 rows: a flat slab or helmet wedge with an eye-slit. Never a ball.
- Vertical rhythm on a 17-row canvas: 1 head / 2 neck / ~6 coat / 3 legs /
  1 ground. The coat occupies roughly half the canvas (rows 5–12 of 17).
- Shoulders narrow and sloping, narrower than the coat; the coat flares wide
  while body and legs stay narrow — the figure reads tall-and-thin even at 17
  rows. Neck long, with large void on both sides: negative space is the
  megastructure, never leftover canvas.
- Ground = 1 row of floor contact; the shadow cleaves to the floor and
  shifts opposite the anticipation lean.
- Figure luminance order, inside out: ▓ lit coat core → ▒ edge light → ░
  dark hems, a secondary light on one side, and the `•` eye mote as the apex
  that persists through a blink. Motion arcs are closed loops of
  anticipation → action → settle, dressed in ▒ feathering, ░ drag-tails, and
  squash-and-stretch on breath.

The near-miss-not-Atari principle: surfaces mimic Nihei's *proportion and
scale* — gaunt, elongated, tiny heads, huge coats, vast negative space —
never a copied shape. The bar is "a fluid pixellated near-miss render in the
Nihei register, not an Atari placeholder", per the v4-vs-v3 pairwise verdict
([operative-frames.md](operative-frames.md)). The adopted figure is now the
gen-5 standardized two-arm/two-leg rig
([assistant-interface.md](assistant-interface.md)); it holds the register by
keeping the constants — small head, slit mote, dark coat, void — not by
restating v4 verbatim.

## 4. Palette and luminance

No invented hexes. Existing surfaces own the colors; this register names
their disciplined use ([operative-frames.md](operative-frames.md),
[presentation-boundary.md](presentation-boundary.md)):

- Do: dark coat as the figure body (▓▒░ interior); pale eye-slit with `•`
  mote as the luminance apex. Backgrounds read as megastructure void, darker
  and quieter than the figure's edge light.
- Do: a lit floor slab with a cast ground shadow under any grounded pose.
- Do: optional color styling that never changes a fact — a refusal "remains
  a literal refusal even when a report gives it an optional visual
  treatment".
- Don't: introduce a saturating hue no existing surface carries; let panel
  chrome outshine the eye-slit; style a refused or dead state with a
  positive-affect color; rest legibility on color alone — every status line
  must be readable by an operator who has never read the fiction
  ([../research/2026-08-11-clean-architecture-roguelike-run-review.md](../research/2026-08-11-clean-architecture-roguelike-run-review.md)).

Extrapolation OPTIONS (clearly marked, not canon): a future palette pack
could register chips *extracted from* existing frames (coat-core, slit,
void, floor) instead of new values; the terminal palette is already the
themes in use (e.g. `--theme=matrix` as graded by
[`../../scripts/grade-interface`](../../scripts/grade-interface)). Nothing
here proposes new hex codes.

## 5. Display vocabulary

Optional aliases are presentation-only. Every row below is
`perceptual:true` scope: display data, never canonical, never an input to
governance or selection.

| Operational term | Optional display alias | Provenance pointer |
|---|---|---|
| run mounted on a course | "quest" — character mounts the course, one caption with the objective | `gamified-runs.md` event table |
| `:evacuated` run close | "returned artifact cache" (dormant) | research review, `docs/aesthetic.md` |
| `:dead` close / terminated session | death frame; successor spawns per the roguelike rule | `gamified-runs.md` event table |
| green checkpoint | "quiet maintained sector" (dormant) | research review, `docs/aesthetic.md` |
| afterlife-record | "salvage record" (dormant) | research review, `docs/aesthetic.md` |
| guardrail | "Safeguard" — a guardrail, never an armed automated actor (dormant) | research review, `docs/aesthetic.md` |
| untrusted external agent or adapter | "Silicon Life" — never a person (dormant) | research review, `docs/aesthetic.md` |
| validated protective boundary | "Garde" (dormant) | research review, `docs/aesthetic.md` |
| refusal | none — renders the literal refusal label | `gamified-runs.md` setback row |
| `alert` / `victory` | one-shot quiet caption, plays once and settles | `buddy-menu-spec.md` state table |

Provenance pointers resolve to [gamified-runs.md](gamified-runs.md),
[buddy-menu-spec.md](buddy-menu-spec.md), and the roguelike research
review's `docs/aesthetic.md` bullets
([../research/2026-08-11-clean-architecture-roguelike-run-review.md](../research/2026-08-11-clean-architecture-roguelike-run-review.md)).
Dormant rows are archived vocabulary, not active copy: admitting any of them
still requires the four-field pack record and the public-release review of
[reference-lexicon-policy.md](reference-lexicon-policy.md).

## 6. Dosage ladder

Ascend only when a surface earns it; every rung above the first is optional
display data:

1. **Kernel plain terms** — the default renderer needs no reference pack
   ([presentation-boundary.md](presentation-boundary.md), "Original
   lexicon").
2. **Named-surface alias pack** — the four-field record (surface, original,
   reference, provenance), removable without a migration or behavior change
   ([reference-lexicon-policy.md](reference-lexicon-policy.md)).
3. **Event narration** — closed vocabulary `quest` / `victory` / `setback` /
   `reward` / `death`, derived only from recorded run state transitions,
   carrying `perceptual:true` ([gamified-runs.md](gamified-runs.md)).

Boundary law, verbatim from
[presentation-boundary.md](presentation-boundary.md): "Display aliases never
enter canonical records or package APIs" and "A reference pack cannot carry
canonical state, receipts, CLI flags, use-case outcomes, authority, or
execution instructions." Every optional display value keeps its original
fallback, and the canonical term renders alongside.

## 7. Grade hooks (future criteria)

Concrete assertions a future deterministic pass of
[`../../scripts/grade-interface`](../../scripts/grade-interface) COULD
check. Criteria only — nothing here is implemented today; the script stays
the vision-rubric loop of [interface-grading.md](interface-grading.md).

- exactly one caption per state snapshot;
- zero ALL-CAPS display lines (literal state or token text exempt);
- negative-space minimum: the operative frame keeps ≥1 head-width of void
  on two sides;
- one-shot transitions: `alert` / `victory` advance on the event tick and
  never replay while the state is unchanged — no loop, no nag;
- co-presence: a perceptual alias renders with its literal term alongside;
- luminance apex: the brightest region of a figure frame is the eye-slit
  mote, not chrome or borders;
- unmapped-state fallback: a state outside the event vocabulary renders its
  literal term.

## 8. Non-goals

- No implementation: no scripts, tests, renderers, or palette values.
- No new event vocabulary; the closed set stays closed.
- No reference-pack activation or release; none is active, and each entry
  still requires the lexicon policy's product review.
- No change to canonical terms or records — this register cannot rename a
  fact.
- This is not the frame catalog
  ([operative-frames.md](operative-frames.md)), the honesty model
  ([gamified-runs.md](gamified-runs.md)), or the boundary law
  ([presentation-boundary.md](presentation-boundary.md)); it registers their
  display consequences.

## 9. Open questions

- Freeze the gen-4 ratio constants as register canon, or re-measure against
  the adopted gen-5 rig per surface?
- Will any dormant alias (Safeguard / Garde / Silicon Life) be submitted for
  lexicon release review?
- Extract palette chips from existing frames into a registered chip set, or
  leave them implicit? Which surface earns the first named-surface alias
  pack?
- Grade hooks: deterministic assertions, vision-rubric extensions, or both?
- Where does caption copy live long-term: script constants today, pack
  fields later?
