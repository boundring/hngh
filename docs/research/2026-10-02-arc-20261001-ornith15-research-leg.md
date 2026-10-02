# What quality/VRAM envelope does ornith-ai/Ornith-1.5-9B-GGUF at max_seq_length 8192 hold as the standing local research leg on the unsloth llama-server, and should unsloth_attempt cap beat load-pins at the registry server_observed window (automation/lib/model.sh:296-301)?

Status: crystallized 2026-10-02 from research line `arc-20261001-ornith15-research-leg`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-arc-20261001-ornith15-research-leg.md.

# research beat — crystallization (line record)

_line: What quality/VRAM envelope does ornith-ai/Ornith-1.5-9B-GGUF at max_seq_length 8192 hold as the standing local research leg on the unsloth llama-server, and should unsloth_attempt cap beat load-pins at the registry server_observed window (automation/lib/model.sh:296-301)? | state: contracting -> contracted_

## Standing access caveat (bounds this record)

Unchanged across every beat of this line: no read access to this repository's working tree or to the hngh kernel tree at `[redacted path] from this vantage. Tier scheme carried through: **[given]** (supplied by the line state or harness), **[derived]** (defensible arithmetic/logic over given facts), **[unverified]** (needs an on-host or external read). Nothing in this record promotes tier-3 to tier-1. Paths named below are only those the line state itself supplies.

## Crystallized findings

**F1 [given→derived] The line closes with its central artifact still unread.** The six lines `automation/lib/model.sh:296-301` were never read in any beat. Everything about `unsloth_attempt` policy is therefore conditional on which of two intents that code encodes. This is the line's most important honest limitation and the first open thread.

**F2 [derived] The VRAM envelope at 8192 context, as bounded arithmetic (not measurement).** For a ~9B llama-class GGUF, using standard llama.cpp quant bitrates applied to 9×10⁹ parameters:

- Q4_K_M ≈ 5.3–5.7 GiB weights
- Q5_K_M ≈ 6.4–6.6 GiB weights
- Q6_K ≈ 7.4–7.6 GiB weights
- Q8_0 ≈ 9.5–9.7 GiB weights

KV cache at full 8192 window, assuming llama-class geometry (e.g. 32 layers, 8 KV heads, 128 head-dim, fp16): ≈ 1.0–1.1 GiB, plus a compute/scratch buffer of roughly a few hundred MiB at that context. Totals: **Q4_K_M ≈ 6.5–7 GiB; Q5_K_M ≈ 7.5–8 GiB; Q6_K ≈ 8.5–9 GiB; Q8_0 ≈ 10.5–11 GiB.** Two explicit caveats: Ornith-1.5-9B's actual architecture (layer count, KV heads, any GQA shape, whether the repo ships all four quants) is **[unverified]** — I cannot inspect the ornith-ai repository from here; and any KV quantization setting on the server config would shrink the KV term, also **[unverified]**. These are predictions to be replaced by R2's measurements, not results.

**F3 [derived] Idle-post-load footprint is the wrong number to pin against.** KV allocation at 8192 context grows as the window fills; an idle footprint passes a load-time check and then OOMs mid-generation. Peak-under-full-window is the only safe basis for a load-pin. This failure mode — not the raw envelope — is the concrete thing this line existed to catch, and it stands regardless of which quant wins.

**F4 [derived] Under either reading of the cap question, a constant `unsloth_attempt` cap is wrong.** The two candidate intents of `model.sh:296-301`:

- *Resolve before the registry `server_observed` window closes:* N ≤ ⌊(W − margin) / (t_load + t_backoff)⌋ — N shrinks as measured load time grows.
- *Coverage across the window:* the inequality inverts; N must be large enough that the retry span covers W.

Both forms take `t_load` from the envelope measurement and `W` from registry `server_observed` timestamps, so N should be **computed at pin time**, not hardcoded. This is the line's crisp answer to its second question: *should the cap beat load-pins at the window?* — not as a fixed race, but as a formula whose inputs are the measured load time and the observed window. Which inequality applies remains blocked on T1.

**F5 [derived, protocol-shaped] Quality floor is a selection, not an assertion.** The standing leg should be the smallest quant whose degradation on the line's eval is within tolerance, with Q5_K

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
