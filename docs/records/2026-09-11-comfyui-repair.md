# ComfyUI user-space repair + imagegen local leg (2026-09-11)

## What was broken

- Packaged ComfyUI 0.34.0 (`/usr/bin/comfyui` -> `/opt/comfyui`, pacman) ships a
  python 3.14.7 venv whose **PyTorch post-install never succeeded** (mid-flight
  failure in the packaged install; launcher refuses with "retry: sudo pacman -S
  comfyui"). No torch, no diffusion.
- `/opt/comfyui` is root-owned: even with a working interpreter the server
  crashed in `UserManager` creating `/opt/comfyui/user`
  (`PermissionError`, /tmp/comfyui-run3.log). Not fixable in user space; the
  server must run with user-space `--user-directory/--output-directory/
  --temp-directory` overrides instead.
- No checkpoints anywhere on the box; `/etc/comfyui/extra_model_paths.yaml` an
  empty placeholder.
- Previous attempt's evidence (/tmp/comfyui-run*.log): run1 a mismatched torch
  build ("No CUDA GPUs are available"), run2 a torchvision ABI mismatch
  (`torchvision::nms does not exist`), run3 the root-owned-dir crash. The
  desktop text model (llama-server, 27B-class GGUF) may hold 13-16 GB of the
  21.4 GB card when resident -- the VRAM gate in imagegen-submit exists for
  exactly this (design s4).

## The repair (all user space)

- venv `~/.local/share/comfyui-venv312` (uv-built, python 3.12.12) with
  **torch 2.14.0+rocm7.2** from the rocm7.2 index; ROCm HIP runtime reports
  `torch.cuda.is_available() == True` on the RX 7900 XT **without**
  `HSA_OVERRIDE_GFX_VERSION` (RDNA3 is natively supported by this build).
- Checkpoint `v1-5-pruned-emaonly.safetensors` (4.05 GB) at
  `~/.local/share/comfyui-models/checkpoints/`.
- `~/.config/comfyui/extra_model_paths.yaml` -> base
  `~/.local/share/comfyui-models` (checkpoints subdir).
- User-space runtime dirs: `~/.local/share/comfyui/{user,output,temp}`.

## Operator-facing permanent start command

```
cd /opt/comfyui && ~/.local/share/comfyui-venv312/bin/python main.py \
  --listen 127.0.0.1 --port 8188 \
  --user-directory ~/.local/share/comfyui/user \
  --output-directory ~/.local/share/comfyui/output \
  --temp-directory ~/.local/share/comfyui/temp \
  --extra-model-paths-config ~/.config/comfyui/extra_model_paths.yaml
```

Operator-run service posture: automation never starts/stops it; start-verify-
stop always (GET / 200 -> generate -> stop). Add `--cpu` when the VRAM gate
skips (text model resident): SD1.5 512x512 on CPU ~1-3 min.

## GPU-window constraint

`rocm-smi --showmeminfo vram` GPU-0: 21.4 GB total. The text model occupies
13-16 GB when resident; idle it holds ~1.4-1.6 GB. The usable diffusion window
is only when the text model is NOT resident. Coordination point: the VRAM gate
in `automation/jobs/imagegen-submit.sh` (default threshold now 8 GB: a
resident 27B text GGUF is 13-16 GB -> skip; ComfyUI's own SD1.5 cache peaks
~4-5 GB -> proceed; the previous 4 GB default false-positived on the imagegen
leg's own residency).

## Verified pipeline (GPU, 2026-09-11 16:23-16:26 UTC)

- Server up (127.0.0.1:8188, GET / 200, checkpoint registered via
  object_info), window open (1.6 GB used).
- `POST /prompt` with `{"prompt": <api-graph>}` (the graph itself is NOT the
  body -- it must be wrapped) -> poll `/history/<pid>` -> fetch `/view`.
- 512x512 SD1.5 smoke: HTTP 200, PNG, **10.2 s** end to end on GPU.
- Section-spacer regen (style row seed 907, 1280x320): **10.1 s**, PNG at
  `docs/media/imagegen/section-spacer-comfyui-20260911T202558Z.png` (vs the
  pollinations bootstrap PNG of 09:59; local leg is the deterministic,
  self-hosted replacement -- same style family, same seed reproducibility).

## Local-leg cutover

- `automation/jobs/imagegen-submit.sh` local leg is live: API-format SD1.5
  graph (CheckpointLoaderSimple -> CLIPTextEncode x2 -> KSampler ->
  EmptyLatentImage -> VAEDecode -> SaveImage) built with jq from the style row
  (prompt template, size pair, seed), POST/poll/fetch fail-closed.
- `automation/config/cadence-params.tsv` `imagegen-endpoint` ->
  `http://127.0.0.1:8188` (set ONLY after server verified + generated).
- Gates still live: VRAM (8 GB default), loadavg, empty-endpoint fail-closed
  skip, timeout -> exit 1 no partial files.
- Smoke glue promoted: `automation/scripts/comfyui-smoke.sh` +
  `comfyui-smoke-workflow.json` (operator starts server, runs the script,
  stops the server).
- Night-beat tenancy gate (design s4 gate 3) remains deferred -- it needs the
  cadence schedule; not part of this repair.

## Remaining operator steps

- Optionally install the start command as a user systemd unit (on-demand
  socket activation) -- not required for the cadence leg (it skips fail-closed
  when the endpoint is down).
- Keep the text model and ComfyUI from overlapping: the VRAM gate is the
  coordination point; if the text model is resident, ComfyUI with `--cpu` is
  the fallback (slow but real).
