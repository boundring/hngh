# Manga comprehension pipeline -- multimodal narrative analysis (P0)

Status: P0 LANDED (2026-09-12). The operator's directive: the metrics
layer (jobs/manga-metrics.py, docs/research/2026-09-12-manga-collection-
study.md) measures geometry but the output is still "devoid of soul" --
the cure is hngh COMPREHENDING the collection, not measuring gray
histograms. This pipeline adds the narrative layer: a multimodal model
reads chapter spreads and distills HOW the story is carried.

## Layer contract (binding)

- metrics = geometry (panel bands, ink, tone); vision = narrative
  (panel flow, reading order, what imagery alone communicates). The
  two layers read different things and never merge pixels.
- Provenance unchanged: pages temp-extracted, described, deleted;
  lessons JSON (docs/research/) is the only artifact. No artist names
  in prompts (SPREAD_PROMPT says so explicitly) or in lessons.
- Calls bounded: MAX_SPREADS spreads/run (default 4, 2 pages each =
  8 images max in practice; operator cap for this beat honored at 4).

## Vision-capability inventory (2026-09-12, live-verified)

| Leg | Verdict | Evidence |
|---|---|---|
| unsloth local (studio :8888 -> llama-server) | VISION, live-verified | Studio spawns llama-server with --mmproj for BOTH Qwen3.8-27B and Ornith-1.0-9B GGUFs (unsloth-studio.service journal); /v1/models reports capabilities ["completion","multimodal"]; synthetic 2-rectangle fixture described correctly; real manga spreads processed end-to-end |
| ollama (gemma-4-12B QAT, Ornith 9B GGUF) | not vision-configured | no mmproj passed by the ollama_chat leg; treat as text |
| HF cache | text/LUT/video models only | Qwen3.8-27B variants, LTX-2.3, flux2-klein encoder, Qwopus -- no llava/moondream/minicpm-class model locally |
| kimi K3 | text-only | K3/kimi-for-coding coding endpoint; no vision variants in the model gate rows |
| ocgo glm-5.3-flash | text-only today | Go gateway model; no vision variant configured. glm vision variants may exist upstream -- UNVERIFIED, re-check when the Go models list changes |
| deck (llama.cpp/vulkan :8082) | no mmproj loaded | deck-model-endpoint row serves a text GGUF; adding an mmproj there is a deployment step |

No new model download needed: the unsloth leg IS the vision path
today. Operational reality: studio kills the spawned llama-server on
idle (port 48593 was up at probe time, gone minutes later); requests
to :8888 respawn it (~20-40s cold start + vision encode), so a run of
4 spreads costs ~2-3 minutes wall.

## Pipeline design (jobs/manga-vision.py)

1. SAMPLING: pick_spreads() selects up to 4 consecutive-page pairs at
   the quarter points of the archive's page sequence (chapter
   transitions carry the arc); members 0-1 skipped on long sequences
   (cover/TOC pages -- volume 1's first live run proved the model
   would otherwise spend its budget describing title typography).
2. PER-SPREAD VISION PASS: one bounded multimodal call with a strict
   JSON prompt: panel_flow, reading_order, narrative_mode
   (image-only | dialogue-only | mixed), dialogue_elements,
   imagery_carries, page_turn_hook.
3. RETRY (mirrors unsloth_chat's cure): empty content (thinking ate
   the budget) -> one retry budget x4 + enable_thinking:false; output
   without "{" -> one more thinking-off retry; reasoning_content is
   the last-resort text (never parses as lessons -- by design).
4. DISTILLATION: distill() folds spreads into lessons JSON:
   beats[] (narrative_mode + flow + hook + imagery per spread),
   ratios {image_only, dialogue_only, mixed}, grammar_notes,
   hooks, script_annotation.
5. FEED: the manga-draft.py script layer gains the narrative-mode
   register -- each beat annotated image-only / dialogue-only / mixed.
   The BLAME!/Homunculus contrast lives exactly on this axis: Blame
   v01 live sample reads 0.50 image-only / 0.50 mixed / 0.0
   dialogue-only (docs/research/2026-09-12-manga-vision-lessons-
   blame-v01.json).

## What P0 produced vs deferred

Produced: the pipeline (sampler, vision call, distiller, CLI, hermetic
tests with a stubbed VISION_CALL seam + MANGA_VISION_TEST_STUB hook);
one live Blame v01 lesson JSON; the capability inventory above.

Deferred (deployment steps, not design gaps):
- Per-title progression studies (Homunculus image/dialogue alternation,
  modern-Nihei dialogue drift) -- queue the runs, same pipeline.
- STYLE_CORE/bank wiring: consume lessons JSON in manga-draft.py's
  script pass (the register annotation is designed but not imported
  there yet).
- Deck leg vision: add an mmproj to the deck server's llama.cpp
  invocation if overflow vision capacity is ever needed.
- Facing-page (true spread) stitching: samples are consecutive pages,
  not bound-book facing pages.
