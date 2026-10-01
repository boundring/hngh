# Ornith-1.5-9B-GGUF local research leg probe (2026-10-01)

Date: 2026-10-01. Scope: unsloth llama-server load-out + one delegated
probe; no automation code changed.

## What ran

- Loaded `ornith-ai/Ornith-1.5-9B-GGUF` on the local unsloth
  llama-server (`http://127.0.0.1:8888`, user unit
  `unsloth-studio.service`) with the lowered research window
  `max_seq_length 8192` (registry `server_observed`; card native
  262144). Load accepted in ~80 s; the runtime fetched Q4_K_M (the
  advertised Q6_K was not what the repo served).
- VRAM after load: dGPU (Navi 31, 20 GiB) used 9,235,771,392 B
  (≈ 8.6 GiB) via `rocm-smi` (`amd-smi` is broken on this box: no
  amdsmi module).
- Functional probe: one `/v1/chat/completions` round-trip, 300
  completion tokens in 7.6 s ≈ 39 tok/s wall.
- Real-work probe: delegated jcode session `ornith15-leg-probe`
  (PROVIDER=unsloth, unpaced local leg), read-only analysis of bead
  hngh-1ec. Completed rc 0 in 294 s; log
  `logs/overnight-jcode-ornith15-leg-probe-20261001T171157.log`. Its
  verdict drove the hngh-1ec fix shape: `catalog()` in
  `automation/lib/hngh_home.py:81-104` dedupes on the RAW caller string
  (no expanduser on incoming or stored cells), so migration rows with
  tilde forms and later absolute rows coexist as duplicate
  `dispatch-edition` entries in `~/.hngh/catalog.tsv`.

## Standing lane decision

Ornith-1.5@8192 is a viable standing research leg: ~8.6 GiB VRAM leaves
headroom beside other load-outs on the 20 GiB card, throughput is
sufficient for analysis probes, and the delegated lane runs unpaced.

Follow-up candidate (not done here, no model.sh change): cap beat
load-pins at the registry `server_observed` window in `unsloth_attempt`
(`automation/lib/model.sh:296-301`) so a drifted pin cannot refuse.
