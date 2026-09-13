# Manga collection use policy -- 2026-09-12

Status: RECORD (operator-stated policy, recorded same day). Governs
hngh's use of the operator's personal manga collection
(~/Documents/manga, inventoried read-only by jobs/manga-manifest.py,
studied by jobs/manga-metrics.py per
docs/research/2026-09-12-manga-collection-study.md). Provenance law of
that study remains binding; this record extends it where the operator
has stated a position.

## (a) Study, never redistribution

Pages are studied for composition and narrative METRICS (panel bands,
ink/tone coverage, gutter rhythm -- landed in the collection study).
Pages are never redistributed: nothing is uploaded, published, or
committed to the repo. Pixels are temp-extracted, measured or
transformed locally, and deleted (the read-only + temp + delete
pattern).

## (b) Character/concept callbacks = transformative reference

Quips, easter eggs, and flavor text in hngh reference the collection's
concepts, register, and archetypes DESCRIPTIVELY: no copied panels, no
artist names in prompts (test-enforced contract, TestStyleCore), no
scanned pages. This extends the existing pattern: the Saga's "creatures"
ARE the bestiary cause classes (docs/design/bestiary.md), and the
display register's slit-faced watch already speaks the megastructure
genre. The seeded callbacks (2026-09-12):

- quips.py patrol/machine_hall banks: the corridors that are always
  quiet; the builders who never stopped; the stair that goes down a
  level the map does not keep.
- manga-draft.py NARRATIONS/MARGIN_NOTES: floors past the floor plan;
  mushroom season in the storeroom; the cheek that grew back; tengu
  near stairwell 12.
- digest-public.py SAGA_EPITHETS: one megastructure epithet per
  bestiary cause class (the builder past its drawing, the old
  safeguard pacing a finished beat, the door keyed to one hand alone).

Subtlety law: the callback is for an operator who knows the source; a
stranger reads it as original hall flavor. No titles, authors, or
work-specific proper nouns ride inside generated output or prompts.

## (c) Collage/decoration source material (OPERATOR'S POLICY -- recorded position)

The operator's stated position, recorded verbatim in substance:
"with some precedent of collage as a valid art form, we consider any
or all of the art in that collection as available for Hngh's use in
decoration of interfaces and flavoring in general. The collection of
so many character images, it can get used for simple animations, easy
material for future Hngh works. If it's edited enough, it's no longer
the original work."

Structured: extracted character/environment images from the OPERATOR'S
OWN collection may be used as SOURCE MATERIAL for collage/editing in
decoration (dashboard backgrounds, dispatch flourishes, panel
hybrids). The pipeline: jobs/manga-collage.py (crop + recolor to the
register palette + SVG overlay recomposition -- the "edited enough"
transformation).

Honest limits, recorded with the position:

- The operator's rationale rests on personal use + collage as an art
  form + SUFFICIENT transformation. This is the operator's stated
  opinion, not a legal clearance; the transformation threshold
  ("edited enough") is a gray zone the operator accepts knowingly.
- The same rationale does NOT cover public redistribution of UNEDITED
  source panels: a raw page leaves the collection is a different act
  than a collage derivative, and no committed artifact may be a
  verbatim page.
- Every committed derivative must therefore be measurably transformed
  (recolored, recomposed, overlaid -- never verbatim), and cited to
  the collection study, not to the original filename.

Overarching position, recorded later the same day (OPERATOR'S POLICY):
"So far as I'm concerned, all of the art is fair use if altered enough
anyway. That's collage." Structured: substantial alteration transforms
the work -- the transformation threshold is the collage pipeline
itself. If the output is altered enough (crop + recolor + recompose +
overlay), the result is hngh's own art, not a derivative riding on the
original. The pipelines enforce this by construction: every output
carries the transformation's effects (recolor, overlay, recomposition)
-- never a raw crop. The gray-zone caveat above still applies: this is
the operator's stated opinion, recorded as policy, not a legal
clearance.

## (d) No pages in the repo

The provenance discipline stays: no scanned page, no raw panel, and no
untouched crop is committed. Committed decoration lives in
docs/media/collage/ and is the OUTPUT of the transformation pipeline
only. The collection itself is never referenced by path or filename in
public-facing artifacts -- provenance cites "collection study,
2026-09-12".

## (e) Attribution (titles/authors, cited not scanned)

The works behind the style studies, cited by title/author as reading
references (not page-scanned into any artifact):

- Blame!, Abara, Biomega, Tower Dungeon -- Tsutomu Nihei
- Dai Dark, Dorohedoro -- Q Hayashida
- Hanaotoko -- Taiyo Matsumoto
- Astro Boy (collection volumes) -- Osamu Tezuka
- Heaven's Door, G -- Keiichi Koike
- Homunculus -- Hideo Yamamoto
- Japan Tengu Party Illustrated; National Quiz -- authors as labeled
  in the collection (folder labels carry the filing; the works are
  cited by title here).

## (f) Fan-translation dialogue as bank source material (OPERATOR'S POLICY)

The operator's stated position: "fan translation dialogue is all
useable. Direct quotes should be fine, they're translated away from
each author's true intent in Japanese." Authorized: the fan-translation
text in the collection's dialogue bubbles may seed hngh's banks
(quips.py, manga-draft.py pools, callbacks, easter eggs).

Provenance discipline, recorded with the position:

- The translation itself is the source. The original author's intent
  is already one step removed (translated by the fan translator), so
  quoting or echoing the fan-translation phrasing in hngh's banks is
  an additional transformation step, not a direct copy of the original
  author's prose.
- When a specific bank entry is inspired by a specific observed line,
  the style-research doc (docs/design/manga-style-research.md) cites
  the title/work it came from.
- Never attribute a quote to the original author in the original
  language -- no Japanese text in banks, no author-byline quotes.
- The subtlety law of clause (b) still governs generated output: no
  titles, authors, or work-specific proper nouns ride inside generated
  output or prompts.

## (g) Character-image homage, light-touch (OPERATOR'S POLICY)

The operator's stated position: "Hngh not being anything like a paid
product, open-source as hell, I'm pretty sure we can get away with
using animated characters from each work as homage." Authorized:
character images from the collection as homage decorations BEYOND the
heavy-transformation collage pipeline of clause (c) -- light-touch use
included: character crops as dashboard decoration, panel backgrounds,
interface flourishes, avatar references.

Wiring: jobs/manga-collage.py --homogeneous (the homage mode: crop +
scale + tone-match to the register palette + opacity blend + border
overlay; no heavy paint pass). The distinction: collage = heavy
transformation; homage = light crop/scale/opacity. Both operate under
the overarching position in clause (c) (substantial alteration is the
threshold; the pipeline enforces it by construction -- even homage
output is recolored and overlaid, never a raw crop) and both cite the
collection study.

The operator's rationale, recorded: non-commercial, open-source,
personal collection.

Honest limits, unchanged:

- No full-page reproduction, no verbatim-page redistribution (clause
  d's no-pages-in-the-repo law stays).
- Attribution in published outputs credits the TITLE, not the
  publisher.

## Cast naming suggestion (the operator's call, kept generic in code)

The manga-cast cameos (bureaucrat/engineer/nightwatch,
config/manga-cast.json) stay generic descriptors in code. If the
operator later wants sourced archetype names, collection candidates:
the smoke-masked head that talks back (a Dorohedoro-style gruff
face), the pale-slit watch figure (the register's own coat), the
wobbly-line craftsman (a Matsumoto-style scrappy worker). Naming is
the operator's call; nothing in code renames until directed.

## Pipeline status

- Landed: jobs/manga-collage.py (P0 skeleton), one committed sample
  (docs/media/collage/), tests in automation/tests/test-manga-collage.py
  (output validity, transformation non-verbatim, provenance hygiene).
- Not landed: interface wiring (dashboard background slot), simple
  animations from character crops, public-release review of the
  decoration assets (the reference-lexicon-policy review gate applies
  if these leave the operator's surfaces).