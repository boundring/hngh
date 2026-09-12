# 2026-09-12 -- gag-manga publisher pipeline (design + P0 slice)

Operator directive: evaluate the GDELT Web News NGrams 3.0 dataset and
design a comic/manga-style newspaper publisher -- each article is panels
with illustrated characters/environments, dialogue and SFX, narrative
blocks, procedurally dramatized from GDELT events. hngh already does the
individual actions (GDELT ranking, image generation, HTML rendering,
review machinery); the missing pieces are the knowledge base and the
joining tissue. Prior art named by the operator:
github.com/iandreafc/gdeltnews (article reconstruction from ngrams 3.0).

## Publisher abstraction (the design frame)

The operator's framing: hngh supports "publishers of nearly any kind of
content." The manga paper is one backend of a generic shape, not a
one-off script:

    source adapters  ->  interpretation  ->  render backends
    (gdelt-news.py,     (rank/annotate/      (digest-html.py = newspaper,
    rss lane, ...)      dramatize)           manga panels = comic, ...)

Today's newspaper is the first concrete instance. The manga backend
reuses the same source adapters and adds its own interpretation stage
(dramatization) and render stage (panel SVG + image). Future backends
(audio brief, TTS podcast; deck; email 'zine) plug the same seams. No
new abstraction was built tonight -- the seam is documented, not coded
(YAGNI until a third backend exists).

## NGrams 3.0 dataset evaluation (fetched + probed live 2026-09-12)

Data shape (blog post + live file probe): JSON-NL, one file per MINUTE,
UTF-8, gzip. Fields: date, ngram (single word/character unigram with
punctuation), lang (CLD2 estimate), type (1=word-segmented, 2=scriptio
continua), pos (article decile 0..90), pre/post (context snippets, up to
~7 words each), url (source article). NOT aggregated counts: every row
is one occurrence with its context, and every row carries article
provenance. Phrases (bigrams+) are recovered by joining across
windows; the codebook documents the centering recipe.

Live probe (window 2026-09-12T16:32Z): one minute file = 3,649,851 bytes
gz, 142,026 rows, 231 unique URLs, languages led by en (70.8k), zh
(29.9k), es, it, de, fr, ar, el. Daily volume approx 5 GB compressed /
approx 200 GB uncompressed text-equivalent; one day = 1440 files.
NOT rolling-window-deleted: the archive runs from 2020-01-01 to present
(blog), and files are plain GCS objects -- download cost per window is
bandwidth only, no license fee. Licensing: GDELT's published datasets are
open reuse with attribution per GDELT policy; the blog post states no
per-file license beyond general GDELT terms. Attribution practice for
hngh: cite GDELT + source URL per item (the existing gdelt-news
discipline already does this for the export CSV).

What reconstruction would add to hngh (honest):

- Phrase-level trend detection: minute files give per-window occurrence
  streams; a phrase watcher ("climate change", "ceasefire", entity
  names) over pre+ngram+post joins gives hour-over-hour surges with
  SOURCEURL receipts -- a sharper trend deck block than GKG theme
  counts, at ~5 GB/day download for full coverage.
- Paraphrase/context corpora for dramatization: pre/post snippets around
  event nouns are free contextual color for panel narrative blocks.
- Article reconstruction (the gdeltnews method): overlap-merge of
  pre/ngram/post fragments per URL reconstructs truncated full text.
  Prior art (Fronzetti Colladon & Vestrelli 2026, Big Data and Cognitive
  Computing 10(2):45) downloads minute ranges, per-language
  reconstructs, then Boolean-filters merged CSVs; quality degrades when
  fragments do not overlap (articles come out truncated).

Verdict at hngh scale: full-window ingestion is a compute/storage hobby
project (5 GB/day compressed, index required). The FEASIBLE slice is
targeted: fetch the 1-3 minute files spanning a chosen 15-minute export
window, grep rows whose pre/post mention the ranked headlines' entity
terms, and use those context snippets as dramatization feedstock +
phrase-surge counters. One minute file (~3.6 MB) per probe is cheap;
60/hour sustained is not, tonight. Queued as research subject
`gdelt-webngrams-reconstruction` (below), riding the existing
gdelt-gkg-trends line rather than replacing it.

## Pipeline stage map (GDELT event -> published panel)

    1. source      gdelt-news.py ranked lanes            EXISTS
    2. ngram feed  minute-file context snippets          MISSING (queued,
                   + phrase surge counters                research subject)
    3. interpret   cross-ref vs knowledge base,          PARTIAL (research
                   trend reflections vs prior beats       beats exist; no
                                                           ngram join yet)
    4. dramatize   plot-type -> gag: scene, dialogue,    P0 LANDED
                   SFX, narrative (manga-draft.py)        (procedural banks)
    5. image       imagegen-submit.sh, manga-panel       EXISTS (row added
                   style row, seed 771                    tonight; local leg)
    6. render      panel skeleton SVG + text bubbles     P0 LANDED (config/
                                                          manga-panel.svg)
    7. review      supportive/adversarial pass           EXISTS (review-
                                                          cycles machinery)
    8. publish     docs/media/manga/ + digest section    P0 LANDED (below)
    9. comedy spin model-leg gag polish, callbacks      MISSING (later)

Gaps the knowledge base must close (research subjects, queued below):
manga panel conventions (reading order, bubble/caption grammar,
screentone language); dramatization plot-type taxonomy (incongruity,
escalation, reversal, slapstick -- which suits which CAMEO lane);
ngram reconstruction methods (overlap-merge, dedup, truncation bounds).

## Attribution discipline (serious, non-negotiable)

- GDELT export rows and ngram context snippets are UNTRUSTED INPUT:
  they pass through the same discipline as any external content
  (docs/records/2026-09-11-research-beat-capture-fix.md,
  lib/docfilter.py pattern) -- ASCII-forced, escaped, never executed,
  never presented as hngh's own voice. Panel text is XML-escaped at
  render (tested).
- No fabricated quotes attributed to real people. The procedural
  dialogue bank is generic reaction comedy, and every panel carries the
  label "[DRAMATIZATION - procedural gag, not a real quote]" plus the
  SOURCEURL. Grounded facts live ONLY in the narrative strip and
  attribution footer; the image and dialogue are explicitly fictional.
- When the model leg joins (stage 4 upgrade), generated dialogue is
  bound by the same rule: no quoted speech assigned to a named real
  person; OSS/social policies (2026-09-11 records) govern published
  output.

## P0 slice landed tonight (dispatch)

Sample dispatch -- one real GDELT lane item drawn from today's ranked
windows (Google search direct-URL change, NOTABLE band), drafted and
rendered with no image (ComfyUI local leg was down at publish time; the
leg skips fail-closed by design):

- [sample-draft.json](../media/manga/sample-draft.json)
  -- the panel plan (image prompt, scene, dialogue, SFX, narrative,
  labeled attribution).
- [sample-panel.svg](../media/manga/sample-panel.svg) /
  [sample-panel.png](../media/manga/sample-panel.png) -- the rendered
  skeleton (caption box, speech bubble + tail, SFX, narrative strip,
  attribution footer). Art slot filled 2026-09-12 via the hngh-operated
  managed ComfyUI start (manga-panel row, seed 771; PNG at
  docs/media/imagegen/manga-panel-20260912T185223Z.png, referenced from the
  SVG's image frame).

The daily digest gets a dispatch section wired in a later slice once
the cadence beat exists (today's digest md is cadence-generated; a
hand-made stub would corrupt the renderer's section parser).

- automation/config/imagegen-styles.tsv: `manga-panel` style row
  (4:3, 1024x768, seed 771, gag-panel template + negative template).
- automation/config/manga-panel.svg: single-panel skeleton (image
  frame, caption box, speech bubble with tail, SFX, narrative strip,
  attribution footer) -- all text server-side, XML-escaped.
- automation/jobs/manga-draft.py: one GDELT lane line -> draft panel
  plan JSON (image prompt, scene, caption, dialogue, SFX, narrative,
  labeled attribution); --render fills the SVG; --image shells the
  existing imagegen local leg (bounded by its own gates).
- automation/tests/test-manga-draft.py (7 tests, wired into
  `make test`): lane-line parse, garbage refusal, style-row parse,
  plan determinism, attribution label, SVG fill + escape, missing-
  skeleton fail-closed.
- Sample draft + rendered skeleton: docs/media/manga/ (digest dispatch
  section links it).

Tests: python3 -B tests/test-manga-draft.py 7/7 OK; full
`automation && make test` green pre-commit; commit-per-green honored
(88a236b3 skeleton, <record> doc commit follows).

Research subjects queued (automation/research-subjects.txt):
`gdelt-webngrams-reconstruction` (minute-file targeted fetch, phrase
surge counters, reconstruction truncation bounds vs the gdeltnews
paper), `manga-panel-conventions` (panel grammar, bubble/caption
norms), `dramatization-plot-taxonomy` (comedy plot types mapped to
CAMEO lanes for stage 4).

## Multi-pass pipeline landed (operator verdict pass, same day)

Operator verdict on the first one-shot panel: "horrifying and needs
extensive revision." The cure is procedural passes, not better
one-shot prompts. Landed (jobs/manga-draft.py):

    pass 1  --script      JSON beats (setup -> reaction -> gag) with
                          per-beat visual notes + stick pose + camera +
                          eye order; narration register (serious-manga
                          deadpan) rides the setup beat
    pass 2  --wireframe   SVG layout contract: panel frame, gutters,
                          pose-library stick figures, focal-action
                          arrow, caption/bubble placement
    pass 3  --components bounded per-region prompts (environment plate
                          768x512, actor pieces 512x768 via the
                          character sheets), max 3 gens/panel, each an
                          imagegen-submit call on the managed leg
    pass 4  --assemble    sentinel-slot composite into the panel
                          skeleton (art under, actors mid, text over)
                          + best-effort rsvg-convert raster

Stages land in docs/media/manga/<name>/ (script.json, wireframe.svg,
components/, panel.svg, panel.png); the legacy pair
(<name>-draft.{json,svg,png}) is refreshed for the standing review and
the dispatch embed. Character consistency: config/manga-cast.json
(appearance descriptor + per-cameo seed -- same seed + same descriptor
= same character across panels). The style lives in one string
(STYLE_CORE, manga-draft.py), studied in
docs/design/manga-style-research.md. Review extension:
publication-review.py now checks the stage files + script beats when a
stage dir exists (pipeline-stages-missing, script-beats-missing).
Render-pass status: GPU-0 held by the resident 27B text model (21.2 of
21.5 GB) -- the VRAM gate skipped the component generations
fail-closed; panel landed with placeholder plates (hand-drawn scene
under, no <image> layer). The next run with a free VRAM window
regenerates the components through the managed ComfyUI leg (2 of the
3-gen budget used).
