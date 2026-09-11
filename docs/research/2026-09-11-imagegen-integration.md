# Image generation integration -- design analysis (2026-09-11)

Operator directive: "However we can get Hngh generating images and
supplementary art, background graphics and animations, characters and
environments, unsloth and comfyUI and other image-gen-workflow
integrations, we'll then be able to take advantage of many
aesthetically-similar art styles to Nihei and Hayashida" (plus Taiyo
Matsumoto, Jiro Matsumoto). Consumer: the public-face redesign
workstream (hero art, section spacers, background graphics).

All probes below ran 2026-09-11 on this desktop, read-only.

## 1. Current asset inventory (probed, not assumed)

| Probe | Result |
|---|---|
| `command -v comfyui` | `/usr/bin/comfyui` EXISTS -- pacman pkg `comfyui 0.34.0-1` |
| ComfyUI installs | Full tree at `/opt/comfyui` (main.py, venv, models/, custom_nodes/) |
| ComfyUI venv | Python 3.14.7, **only pip installed -- PyTorch post-install FAILED**; launcher refuses with "retry: sudo pacman -S comfyui" |
| Model config | `/etc/comfyui/extra_model_paths.yaml` is an empty placeholder |
| Output/input | `/var/lib/comfyui/{input,output}` exist, both empty |
| Checkpoints | **No `*.safetensors` anywhere** (`find ~/ -maxdepth 4`), no model files in `/var/lib/comfyui` or `/opt/comfyui/models` |
| Ports | 8188/7860 NOT listening. Only 8888 (unsloth studio text leg, token-gated; `/v1/models` answers 401 without token file, `/health` 404) |
| Ollama | serving, but only 2 text GGUFs (Ornith-1.0-9B, gemma-4-12B-QAT) -- no vision, no diffusion |
| ROCm | `/opt/rocm` present, ROCk module loaded, `rocminfo` OK |
| GPU 0 | AMD Radeon RX 7900 XT, **20 GB VRAM total, 1.38 GB used right now** (text model NOT resident while idle) |
| Disk | 350 GB free on `/` |

Text-model VRAM reality: the running text leg is `unsloth studio`
(serving `unsloth/Qwen3.8-27B-GGUF` per `automation/config.env`); its
install tree is 13 GB, so a resident 27B-class Q4 GGUF occupies roughly
13-16 GB of the 20 GB card. Idle today it holds ~1.4 GB -- the model
loads on demand. **The usable window for a diffusion model is only
when the text model is NOT resident.**

**The deck's role** (from `automation/docs/DECK-NODE.md` only, no SSH):
the Steam Deck lends its APU via a Vulkan llama-server on port 8082
(tailscale `100.79.162.3`), 7B Q4 text model, ~4.3 GiB VRAM resident,
12.6 tok/s. It is a *single-model text* node: its systemd unit serves
one resident GGUF and its 12.6 tok/s budget implies limited compute.
Running SD-class diffusion there would (a) contend with the
load-bearing `deck-7b` text leg inside one VRAM pool and (b) take
minutes per image on APU compute. Verdict: the deck is **not** a
practical image-gen node tonight; its role stays text overflow.

**Inventory verdict:** this desktop has ComfyUI *installed but broken*
(no PyTorch in the venv, zero checkpoints) and nothing
image-gen-capable currently runnable. Everything else is absent. The
gap between "can generate images today" and "has ComfyUI packaged" is
exactly: torch wheel install + one checkpoint download.

## 2. Integration shapes (compared)

**(a) ComfyUI API headless (port 8188).** Stable interface is workflow
JSON: hngh POSTs `/prompt` (API-format workflow graph), polls
`/history/<prompt_id>`, fetches the PNG via `/view`. Best fit for the
directive: node graphs express loader -> sampler -> save as a fixed,
versionable artifact; prompt/seed/size are single node fields. Same
call shape as the deck leg: an HTTP endpoint the automation tier talks
to.

**The no-daemon problem, addressed honestly:** ComfyUI's API mode IS a
long-running server; a run-per-image CLI mode does not exist for the
API surface (plain `python main.py` still binds 8188). This does not
violate the no-daemon boundary, because that boundary governs the
*kernel* (`src/` never spawns services, watchers, or schedulers --
docs/records passim), and hngh-automation already standardizes the
same posture for llama-server: the text model is an operator-run
process on 127.0.0.1:8888 that the automation tier addresses purely as
an endpoint row (`unsloth-model-endpoint`), fail-closed when absent.
Candidate posture, therefore: **ComfyUI is an operator-run service,
exactly like llama-server.** Automation gains a cadence-params row
`imagegen-endpoint`; empty row = leg skipped fail-closed (identical to
`deck-model-endpoint` semantics); no automation code starts, stops, or
supervises the server. The operator runs `comfyui` when they want art
capacity and stops it when they want the GPU for text.

**(b) SD-webui `--api`.** Absent on this desktop (no
`~/stable-diffusion-webui`, no 7860 listener). It would be a second
heavyweight install duplicating what the already-packaged ComfyUI
does, on an A1111 lineage with slower upstream maintenance. Rejected.

**(c) Hosted/free image API, no key.** The mission guessed "probably
none usable" -- the probe contradicts that: `image.pollinations.ai`
answered **HTTP 200 with a real JPEG** to a no-key GET during probing.
Usable as a zero-install bootstrap leg for mockup art tonight. Honest
caveats: third-party service, no SLA, prompts leave the machine,
model/quality is not ours to pin, rate limits unknown. Fail-closed
fallback leg, never the primary path for committed art.

**(d) ComfyUI CLI run-per-image.** No daemon, but no API either -- each
invocation re-imports torch and re-loads the checkpoint. For an
SD1.5-class checkpoint that is a ~20-40 s model load plus ~30-60 s
torch import per image (order-of-magnitude estimate, not measured).
Viable only for offline batch jobs where per-image overhead is
amortized; wrong shape for the hour cadence. Rejected except as a
manual fallback.

**Recommendation: (a), with (c) as a fail-closed bootstrap leg.** The
API shape matches the deck-leg pattern hngh already trusts; the
operator-run posture keeps the no-daemon boundary intact; (c) lets the
public-face workstream get placeholder-quality art immediately, before
any GPU leg is stood up.

## 3. Style pipeline for the mandated aesthetic

Target artists: Tsutomu Nihei (megastructure, lone figures, ink wash),
Q Hayashida (Dorohedoro grime), Taiyo Matsumoto (fragmented
expressionism), Jiro Matsumoto (screentone desolation). Common
denominator: **monochrome-to-muted ink, high contrast, architectural
scale, organic decay motifs (moss, bone, rust)** -- reachable by base
models with strong style prompting; no per-artist LoRA is required.

LoRA framing (known gray zone, kept honest): community style LoRAs for
"manga ink / dark sci-fi" exist on civitai-class repositories, but
per-artist LoRAs are a legal-and-quality gray zone and unstable to
pin. Pipeline therefore treats LoRAs as **optional hooks**: the
template file carries an optional `lora:<name>:<weight>` slot; empty
slot = prompt-only style. Base model choice (SD1.5 vs SDXL) is a
config value, not baked into templates.

Continuity mechanics: fixed **seed** per asset family (ComfyUI API
exposes seed as a node field; pollinations takes a `seed` param), plus
a pinned **style suffix library**. Same style suffix + same seed +
same checkpoint = reproducible art; the suffix is the stable identity.

Example templates (to live in the committed template file, section 4):

```
# hero banner (3:1) -- vast dark megastructure, lone figure
STYLE_SUFFIX = "monochrome ink illustration, high contrast black and
  white, extreme architectural scale, lone silhouetted figure, moss and
  bone motifs, fine hatching, manga aesthetic, muted accents"
PROMPT = "cathedral-scale machine megastructure at night, one human
  figure on a walkway, cables like vines" + STYLE_SUFFIX
NEGATIVE = "color, photorealistic, soft lighting, text, watermark"
AR = "3:1"  SEED = 511

# section spacer -- skull overgrown with moss, minimalist line art
PROMPT = "weathered skull overgrown with moss, minimalist line art,
  sparse composition, white background" + STYLE_SUFFIX
NEGATIVE = "color, shading, busy background, text"
AR = "4:1"  SEED = 907

# environment -- cathedral-scale machine hall
PROMPT = "cathedral-scale machine hall, catwalks between titanic
  machinery, shafts of light through dust, rust and moss" + STYLE_SUFFIX
NEGATIVE = "color, photorealistic, people, text, watermark"
AR = "16:9"  SEED = 1131
```

(Note: unlike Midjourney, ComfyUI and pollinations take explicit
width/height, not `--ar` flags -- the template stores aspect as a size
pair; `--ar N:1` above is the intent shorthand.)

## 4. hngh integration surface

**Endpoint row.** `automation/cadence-params.tsv` gains
`imagegen-endpoint` (empty by default -- same deliberate emptiness as
the `deck-model-endpoint` row, whose rationale comment is the model to
copy; the real URL lives in `automation/config.env` as
`IMAGEGEN_URL=http://127.0.0.1:8188`, env-overridable). An empty or
unreachable endpoint = leg skipped fail-closed, breadcrumb, no alert --
exactly `deck_chat`'s HTTP-000 behavior.

**Driver script.** `automation/jobs/imagegen-submit.sh` (P0 skeleton
below): reads a workflow JSON + template vars, POSTs `/prompt`, polls
`/history` until completion or timeout, fetches `/view`, writes the
PNG. Prompt text itself can come from the text legs via `model_call`
as any other job input -- imagegen adds no new model-chain code.

**Artifact landing.** `docs/media/` is tracked git (four dashboard
assets already live there; `docs/publication/book.md` references it)
and `automation/media/` does not exist. Since the public-face
workstream consumes `docs/media/`, finished art lands at
`docs/media/imagegen/` (small, committable PNGs); raw/staging output
stays under gitignored `automation/tmp-*`. No new gitignore rules
needed -- the existing file has none for media, by design.

**Quota/GPU pacing.** Image gen runs ONLY when all three hold:
1. text model not resident -- `rocm-smi --showmeminfo vram` GPU-0 used
   below a threshold (suggest 4 GB; today's idle reading 1.4 GB);
2. machine not busy -- reuse `load_busy()` semantics from
   `automation/cadence/hour/33-research-beat.sh` (loadavg1 vs
   ceiling*nproc), which exists as the shared capacity signal;
3. no overnight/night beat in flight -- the night-research job is the
   text GPU's tenant; imagegen never overlaps it (gate on the same
   beat schedule the cadence tick already knows).

Absent any condition: the job skips fail-closed and logs a breadcrumb.
Nothing in the kernel learns imagegen exists (boundary rule).

## 5. Animation reality check

The operator asked for "background graphics and animations." Honest
scope, three tiers:

1. **Looping SVG/CSS animation on the dashboard -- recommended.** Zero
   GPU, bytes not megabytes, committable, animates the generated
   stills (opacity drift, parallax translate, slow zoom on the hero;
   the existing `docs/media/*` dashboard assets show this surface
   already renders such art). All the "motion" the directive wants,
   none of the render cost.
2. **Generated GIF/APNG -- deferred.** Requires repeated GPU frames
   (n seconds of animation = n renders), produces multi-MB assets
   that bloat git, and adds a frame-consistency problem diffusion is
   bad at. Only if CSS proves insufficient.
3. **Video -- out of scope.** No model, no budget, not tonight.

Recommendation: **SVG/CSS-first.** Imagegen stills are the art source;
the dashboard animates them with transforms and blend modes. The
generated still is the deliverable; the motion is markup.

## 6. Verdict + P0

**Verdict:** the directive is realistic on this hardware. The desktop
GPU can host an SD1.5-class checkpoint (2 GB fp16, fits beside the
text model's non-resident idle) or SDXL (7 GB, only during
text-idle windows) under the operator-run ComfyUI posture; the free
pollinations leg covers bootstrap art with zero install. The gap is
one torch wheel install and one checkpoint.

**P0 -- build first:**
1. **Repair/confirm the ComfyUI leg** -- operator action with exact
   commands (below). Until it succeeds, the leg stays fail-closed and
   nothing automation-side blocks on it.
2. **One committed prompt-template file** -- `automation/config/`
   already tracks config artifacts (machine.env.example et al.);
   `automation/config/imagegen-styles.tsv` holds style id, prompt,
   negative, size pair, seed, optional lora slot. The three section-3
   templates are its seed rows.
3. **One jobs skeleton** -- `automation/jobs/imagegen-submit.sh`:
   endpoint row lookup, VRAM + load gates, POST/poll/fetch,
   fail-closed everywhere, breadcrumb on skip. Plus the free-leg
   variant (`imagegen-free.sh` or a `--free` flag) against
   pollinations for immediate art.

Operator repair sequence (documented, not executed here):

    sudo pacman -S comfyui          # retry the failed torch post-install
    /usr/bin/comfyui --listen 127.0.0.1 --port 8188   # probe run
    # risk: the venv is Python 3.14 and ROCm torch wheels for py3.14
    # may not exist; if the retry fails the same way, fall back to a
    # py3.12 venv at /opt/comfyui/venv312 with
    #   pip install torch --index-url https://download.pytorch.org/whl/rocm6.3
    # plus a checkpoint, e.g. an SD1.5 fp16 safetensors into
    # /var/lib/comfyui/models/checkpoints/ (~2 GB, 350 GB free).

**NOT to build:** LoRA training or fine-tuning; video generation; deck
image-gen (contends with the load-bearing text leg); any new Python
dependency in automation (the driver is bash+curl+jq, same as every
other job); any automation code that starts/stops ComfyUI.

**Bootstrap note for public-face:** pollinations accepts the same
style suffixes and seeds, so the first hero/spacer mockups can be
generated tonight without any of the P0 GPU work -- quality gate
applied later against the local leg.