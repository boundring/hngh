# OpenCode Go quota leg (ocgo) — 2026-09-10

T2 GLM subscription leg (operator-armed 2026-09-10), balanced like the
kimi quota leg. Endpoint: `https://opencode.ai/zen/go/v1/chat/completions`
(OpenAI chat-completions shape). Key: env `OPENCODE_API_KEY` (the same key
Pi's opencode-go provider entry uses) -> key file
`~/.config/hngh/opencode-key` (mode 600 required; value never logged).
Gateway requirements (verified live 2026-09-10): every POST must carry a
`x-opencode-session` id (enforced 2026-09-06; headerless reads
400 `MissingSessionID`) — hngh calls are one-shot, so each call sends a
fresh random `hngh-<hex>` id; an identifying user agent is recommended.

## Buckets (per model)

5-hour (~$12, tightest), 7-day (~$30), monthly (~$60). Standing rule R3
(docs/research/2026-09-10-passthrough-and-quota-interleaving.md s4): pace
against the TIGHTEST window, never dump.

## Pacing

`quota_pace_blocked_5h` (lib/model.sh) counts telemetry events
(kind=model, source=ocgo) in the trailing 5 hours and blocks when
`used >= cap` or `used > cap*elapsed/18000 + 1` (one call of grace;
elapsed = seconds into the current UTC-aligned 5h grid window — the
subscription's true reset origin is operator-side, grid alignment just
spreads spend).

Arithmetic (glm-5.3-flash, Go pricing $0.15/$0.50 per 1M in/out): a bounded
call (~10k tokens mixed) costs ~$0.005, so cap 60 calls/5h ~= $0.30 — 40x
inside the $12 bucket (provider's own estimate for the model: ~6,320
requests/5h). Calls-based like every other leg; no cost-tracking subsystem.
Model note: glm-5.3-flash carries the $60/mo limit ($12/5h bucket);
glm-5.3 itself is only $15/mo — switch rows if the default changes.

## Chain position

unsloth -> remote -> ollama -> deck -> **kimi -> ocgo -> lobehub** ->
archive-only. Ocgo sits after kimi (kimi stays the judgment-work lane:
research REVIEW transitions always pin kimi) and before lobehub (premium,
latency-heavy, last). A pace-blocked, capped, or dead ocgo falls through
to the next leg inside model_call — a missed leg never hangs the chain.

## Config rows (automation/cadence-params.tsv)

| row | default | env override |
|---|---|---|
| `opencode-url` | Go chat-completions URL | `OCGO_URL` |
| `opencode-model` | glm-5.3-flash | `OCGO_MODEL` |
| `opencode-cap-5h-calls` | 60 | `OCGO_CAP_5H_CALLS` |
| `opencode-research-share` | 3 | `OCGO_RESEARCH_SHARE` |

Empty/absent row = leg skipped fail-closed. `MODEL_PIN=ocgo` routes there
first (remote + kimi + lobehub skipped). Research beat rotation
(cadence/hour/33-research-beat.sh) pins ocgo every Nth run after the kimi
cycle. `MODEL_USED=ocgo:<model>`; telemetry source `ocgo`.

## Credential health

jobs/credential-health.sh section 6: one authenticated GET to the derived
`/models` path (Bearer, same resolution as ocgo_chat). Headerless curls
against key-gated endpoints are linted by tests/test-probe-hygiene.sh.

## Test surface

`automation/tests/test-model-ocgo-leg.sh` (hermetic): unarmed leg skipped,
fail-closed model gate, stub call + telemetry row + body shape, key-file
600/644 gating, 5h pace block with fall-through, out-of-window events
ignored, hard cap, helper boundaries, dead endpoint fall-through,
MODEL_PIN=ocgo routing. Run: `cd automation && make test` (includes it).

Live confirmation 2026-09-10: one bounded POST (Bearer + session header,
max_tokens 16) -> HTTP 200 completed, 0.67s; Bearer-only GET /v1/models
(the credential-health probe path) -> 200.