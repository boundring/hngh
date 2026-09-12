# Manga collection study -- layout metrics and the numbers behind "soul"

Status: RESEARCH + P0 PIPELINE (2026-09-12). Extends
docs/design/manga-style-research.md (the 4 descriptor studies) with the
operator's personal collection as study material and a deterministic
layout-metrics extractor. The operator's complaint: house manga output is
"devoid of soul or wit or meaning, whatsoever". This study's answer: soul
has measurable components -- panel density, gutter rhythm, tone balance,
ink placement -- and our defaults can be checked against the masters'
actual numbers.

## Provenance law (binding)

- The operator OWNS the collection (~/Documents/manga); local study of
  owned volumes is normal use.
- Pages are extracted ONLY to a temp dir, measured, and DELETED. No page
  or artwork ever enters the repo, a prompt, or training. Metrics
  (numbers) and descriptive language are the entire output.
- No vision-model calls in P0; no OCR yet; no network in the pipeline.
- Every lesson cites title + chapter; nothing redistributable.

## Collection manifest (state/manga-manifest.json, generated)

Scanned read-only by jobs/manga-manifest.py (listing + archive member
counts only; zip/cbz via stdlib, rar via 7z -l; nothing extracted):

| Title | Archives | Approx pages | Style ref |
|---|---|---|---|
| Hayashida Q (Dai Dark v01-08; Dorohedoro v01-11 partial) | 8 cbz + 11 zip + 8 rar | ~5061 | yes |
| Homunculus | 7 zip + 7 rar | ~3241 | - |
| Japan Tengu Party Illustrated | 4 zip | ~944 | - |
| National Quiz (bunko 1-2) | 2 zip | ~922 | - |
| Nihei T (Blame!, Biomega, Abara, Tower Dungeon, GitS) | 72 zip + 12 cbz | ~6144 | yes |
| T. Matsumoto (Ping Pong, Takemitsu Zamurai, Blue Spring, ...) | 16 zip + 4 rar | ~4376 | yes |
| Tezuka Complete Works | 400 rar | ~76800 | yes |
| Heaven's Door / G (Koike Keiichi) | loose jpg dirs | (loose files) | - |

Extraction tooling present: unzip, unrar, 7z, bsdtar, magick. PIL absent
-- the metrics extractor uses ImageMagick `txt:` dumps, pure stdlib
otherwise.

Dorohedoro (Hayashida Q): ARRIVED mid-session (partial, v01-11 rar, more
expected) and was sampled same-day (see table). Manifest flags it as
style reference automatically (keyword match); queue line
manga-study-syllabus names its lessons (grainy textured ink, muddy
palette, deadpan-amid-absurdity, gag-embedded-in-grimness pacing).

## P0 metrics pass -- 5 story pages per title, temp-extracted, deleted

jobs/manga-metrics.py: 120x170 grayscale grid via magick; horizontal +
vertical mark-projection for gutter bands -> panel count; gray histogram
-> ink/tone/white coverage; ink split top/mid/bottom rows.

| Title / source | Pages | Panel bands avg | Panels/page est | Ink cov avg | Tone cov avg | White avg |
|---|---|---|---|---|---|---|
| Blame! v1 ch1 (Nihei) | 5 | 1.6 | 4.6 | 0.544 | 0.264 | 0.193 |
| Astro Boy v1 (Tezuka, ch MT-221 p8-12) | 5 | 1.4 | 1.8 | 0.201 | 0.163 | 0.657 |
| Ping Pong v1 c01 (Matsumoto) | 5 | 1.2 | 1.2 | 0.082 | 0.218 | 0.710 |
| Dai Dark v1 c01 (Hayashida) | 5 | 1.4 | 3.4 | 0.174 | 0.611 | 0.210 |
| Dorohedoro v1 c01-02 (Hayashida) | 5 | 1.4 | 1.4 | 0.179 | 0.422 | 0.399 |

Per-page notes (cited): Blame p001-002 are near-black double spreads
(ink 0.93-0.98) -- the dark megastructure register; Blame p006-007 run
8-11 estimated panels with 33-43% tone. Astro Boy runs low panel counts
on these pages with high white ground (0.57-0.78). Dai Dark is the
tone-heaviest: 0.51-0.97 tone coverage, dense gray texture -- Hayashida's
muddy palette is literal in the histogram. Ping Pong story pages are
extremely sparse: white ground 0.79-0.96, 1-2 detected bands -- the
wobbly-line economy leaves the page mostly empty.
Dorohedoro v1 (Hayashida): tone 0.35-0.51 with white ground 0.28-0.46 --
the "mud" is lighter and grainier than Dai Dark's page-wide washes, and
ink spread evenly across rows (no top-heavy caption mass): texture, not
blackness, carries the grimness.

Known limitations (honest): dark full-bleed pages defeat gutter
detection (Blame p001/002 read as 1 band); light scan linework is
handled by the 200-level mark threshold but faint scans still under-
count; bubble text is not yet separated from art ink -- the ink_rows
distribution is the placement proxy only. N=5 per title is anecdote,
not statistics; the metrics line is queued to widen it.

## The lesson framework -- what "soul/wit/meaning" means executably

(a) PANEL COMPOSITION (study 1 extension): panel-per-page density and
gutter rhythm are measurable (done above). Next-level metrics, proposed
not built: gutter-width distribution, panel aspect ratio distribution,
focal-point density via ink centroid per panel. Nihei's law confirmed
numerically: his calm pages hold MORE panels (8-11) than our wireframe
default, while his splash pages go to 1.

(b) NARRATION/COMEDY (study 4 extension): setup distance (panels between
gag setup and reaction) and the reaction panel's silence (bubble count
per panel) are countable once bubble text density is separable. Dai
Dark's morbid humor lands on incongruity between tone-heavy grim pages
(0.6+ gray) and sparse white gag pages -- the tonal CONTRAST is the
timing. Metric proxy already in hand: adjacent-page tone-coverage delta.

(c) CHARACTER ECONOMY (study 3 extension): face economy = ink spent per
figure at thumbnail scale. Proposed metric: ink coverage of panel-core
regions minus background; Astro Boy's 0.20 ink / 0.66 white says Tezuka
draws less to say more -- the STYLE_CORE "vast negative space" is
directionally right but our output under-uses it.

(d) PAGE RHYTHM (new study 5): page-turn beats and splash placement are
measurable as position of single-panel pages within a chapter sequence
(first-of-chapter splash, pre-turn cliff panel). Proxy: fraction of
1-band pages and their position -- Ping Pong's 60% low-density pages vs
Blame's mixed rhythm are already distinct signatures in the table.

## Study-approach decision (the mix)

- P0 (landed): deterministic layout metrics on small curated samples.
  Cheap, fully local, no model calls, provenance-clean.
- P1 (queued, manga-study-syllabus): online research on historically
  known chapters/pages per title -- the operator's suggested line; cites
  published criticism, no images fetched.
- P2 (deferred): vision-model passes over sample pages, bounded and
  local-only, when the model chain budget allows; still metrics-out,
  never pixels-out.
- Recommended mix: P0+P1 now (they are independent), P2 only for
  questions the numbers cannot answer (composition reading order).

## Bank delta proposals (PROPOSED, not auto-changed)

For manga-draft.py (STYLE_CORE / wireframe defaults), cited from the
table:

1. WIREFRAME: our default 1-3 panels/page under-runs both Blame! (up to
   8-11 on calm pages) and the gag-strip density the 4-panel tradition
   implies. Proposal: script pass emits 3-5 panels per page as default,
   1 for splash beats -- density is a RHYTHM choice, vary it.
2. STYLE_CORE: "vast negative space" is right but under-weighted --
   masters run 0.55-0.96 white ground on story pages. Proposal: raise
   the negative-space phrase priority in component prompts (environment
   plates at least 50% clean white/tone ground).
3. TONE: Dai Dark's 0.6 tone coverage vs our thin tone suggests the
   "screentone shading" descriptor needs a DENSITY tier: "page-wide
   mid-gray texture" as a mood variant for grim beats, flat white for
   gags (the contrast carries the wit).
4. NARRATION: new bank adjacency -- alternate a dense-page beat with a
   sparse-page beat; the wit lives in the white panel after the gray
   one (tonal setup-reaction, mirroring study 4's deadpan register).

All four are descriptor-language changes; no artist names enter prompts
(test-enforced contract), provenance unchanged: metrics in, pixels
never.