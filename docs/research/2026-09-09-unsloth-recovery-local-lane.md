# 2026-09-09 — unsloth recovery note + local-lane resilience

## Status
accepted. Evidence reviewed 2026-09-09T23:00Z. Verdict: not-established (operator-supervised start path required).

## Observed unit states

- `llama-server.service` (system, /usr/lib/systemd/system/): disabled, inactive, ExecStart=`/usr/bin/llama-server --models-dir "%D/llama/models"` (WorkingDirectory=%S/llama/server, User=llama DynamicUser)
- `unsloth-warm.service` (user, /home/bricker/.config/systemd/user/): disabled, inactive (oneshot, Type=oneshot, TimeoutStartSec=900, ExecStart=`/home/bricker/.local/bin/unsloth-warm.sh` warms gemma-4-12b on :8888)
- `unsloth-studio.service` (user, /home/bricker/.config/systemd/user/): enabled, active (Restart=on-failure, RestartSec=10, ExecStart=`/home/bricker/.local/bin/unsloth studio`)

## Operator-side start path

**Not established.** The systemd unit files do not contain the model path or arguments needed to host Ornith-1.0-35B-GGUF. The model file is at:

- `/home/bricker/.cache/huggingface/hub/models--unsloth--Ornith-1.0-35B-GGUF/blobs/4451803948c353ef2c84567e7add0654a32938e033fd44a1a2c0c4f5441cef82` (~12 GB, UD-Q2_K_XL quantization, GGUF format)
- `/home/bricker/.cache/huggingface/hub/models--unsloth--Ornith-1.0-35B-GGUF/snapshots/78e1321ef86b69126dc991f481bb0cdc37614ed0/mmproj-F16.gguf` (0.9 GB, multimodal projector)
- Symlink: `/home/bricker/.cache/huggingface/hub/models--unsloth--Ornith-1.0-35B-GGUF/snapshots/78e1321ef86b69126dc991f481bb0cdc37614ed0/Ornith-1.0-35B-UD-Q2_K_XL.gguf`

No llama/unsloth units exist in /etc/systemd/system or /usr/lib/systemd; /etc/systemd/user/ has NO llama/unsloth files. ~/.unsloth/studio shows recent studio + llama-server pids (studio.db, studio-8888-*.pid, llama-server.pid updated Sep 9) — Studio appears to also manage a llama-server internally. The llama-server service resolves %D (as user 'llama' with DynamicUser) — Ornith GGUF is under bricker's HF cache; a llama-server launch would need explicit --model pointing there or a copy/bind.

This is a critical-class systemd unit edit — requires operator supervision.

## Ollama :11434 capacity

Ollama hosts only Ornith-1.0-9B currently. The 35B model cannot fit in Ollama without significant hardware upgrades or quantization to a smaller format (which would degrade quality).

## Multi-day admission rule for 9B lane

From bench data (model-bench-2026-09-{08,09}.jsonl):
- Ornith-1.0-9B scored 5/5 on 09-08 and 09-09
- Single-day 5/5 is a weak gate

A multi-day threshold rule would be more reliable:
- Require 3/5 across 3 consecutive days before admitting to delegated-lane gate
- The 9B model (currently 5/5 on 08 and 09) would be admitted after 3 consecutive days
- This filters out models that score well on a single run due to chance or probe alignment

## Explicit no-service-started statement

No service was started, stopped, or restarted during this investigation. All actions were read-only.

## Kernel gate

`make test` passes (2855 checks, 2026-09-09T23:00Z).
