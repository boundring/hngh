# 2026-09-12 -- Generated newspaper articles + print front page

Operator directive: "News stories should have articles GENERATED --
short-form summaries procedurally constructed from the item data and
local-model-generated into coherent English, with style guidance and
review. Minimum THREE columns on the front page, printed-newspaper
layouts rather than newspaper-website layouts." Operator steer the same
day: the house humor line is serious-manga narration (Tatsumi's "A
Drifting Life" mode -- deadpan craft-persistence, the mundane played
absolutely straight); articles carry that dryness in the closing/context
line only as a quiet factual observation, never mockery.

## What landed

- `automation/jobs/news-articles.py` -- the wire desk. Ranks the day's
  Deck-A digest items (CRITICAL > NOTABLE > CONTEXT, split-headline
  dedupe), caps at 6 articles/UTC day (cadence-params row
  `newspaper-articles-cap`), and for each builds the prompt FROM the
  item data (headline, severity screen, place, source URL) plus the
  linked source page when fetchable (ONE bounded GET, 10s, standard
  ports only, meta description / first <p>; failure -> article "from
  wire data alone"). Model generation rides the existing chain through
  `lib/model.sh model_call` -- local leg preferred (MODEL_PIN=local),
  quota legs rotate per the existing kimi/ocgo research-share rows on a
  per-run counter. Fail-closed: chain down = no article, never a
  fabricated fallback; a mid-sentence model stop is cut to the last
  complete sentence. Articles commit to `docs/articles/<date>/<slug>.md`
  (metadata comment carries the digest-headline join key, provenance,
  model, image). Hour drop-in `cadence/hour/41-news-articles.sh`.
- Voice law: the prompt bakes docs/design/writing-register.md (Orwell/
  Leonard/Adams) + the deadpan-closer rule from the operator steer; the
  humor-development research line is recorded in
  automation/research-subjects.txt.
- Images: the top 3 articles per edition get ONE scene illustration
  each via `jobs/imagegen-submit.sh`, new style row `news-illustration`
  (768x512, seed 411, monochrome-ink spot-illustration descriptors --
  the manga-adjacent ink art voice without artist names). Fail-closed:
  VRAM/load gate or dead leg = headline-only. Output: docs/media/news/.
- Editions: `digest-html.py` Deck A items whose digest-headline matches
  a committed article render the article body inline in the column flow
  (dateline "PLACE --" convention, story illustration, attribution
  footer as page furniture). `digest-public.py` links the article file.
- Print front page: column-count 3 (2 at <=1279px, 1 at <=799px),
  justified text with hyphenation, hairline column rules, serif display
  headlines (Georgia/'Times New Roman' family fallback), nameplate
  masthead (double-rule bottom border), folio line (date / edition
  number / page 1), section plates with double-rule top border. Existing
  density/contrast palette tokens unchanged.

## Fabrication discipline

Articles may use ONLY the cited headline/severity/place/source data and
the fetched source text; at most one quote, only if verbatim in the
fetched text; unverifiable gaps read "unverified per source"; the
attribution footer names the model draft. DRAMATIZATION labels do not
apply (news, not fiction).

## First real article (2026-09-12, top item, live local model)

Top ranked item: the ConnectWise ScreenConnect CRITICAL (CISA KEV
catalog). Source page fetched; provenance=source; model
unsloth:unsloth/Qwen3.8-27B-GGUF (47s wall). Illustration: the local
ComfyUI leg skipped fail-closed (VRAM gate: text model resident), one
bounded free-leg render landed
`docs/media/news/news-illustration-20260912T195210Z.png` (768x512,
seed 411), wired into the article meta.

## Tests

`automation/tests/test-news-articles.sh` (hermetic, stub-lib stub
serving the local unsloth leg -- the research-beat model_call seam):
generation from fixture items, join key, attribution, wire provenance
(dead URL, no request), cap row, chain-down fail-closed, image budget
<= 3 via stub imagegen, >= 3-column front page, article inline,
dateline, folio, public-edition link. `tests/test-digest-html.py`
column contract updated to 3/2/1; `tests/test-imagegen-submit.sh` row
count updated to 5. Wired into the Makefile.

Verify: `make test` green; `env -i HOME=$HOME PATH=/usr/bin:/bin:/usr/local/bin make test` green.