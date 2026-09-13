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