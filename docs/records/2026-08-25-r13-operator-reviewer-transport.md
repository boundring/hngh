# 2026-08-25 — Rung 13: operator reviewer transport admission

## Scope

Lands the operator reviewer-transport file on the `review` command — the
`reviewer=PATH` option admitting an operator-owned config (endpoint,
model, max-tokens, timeout, token-file) that replaces injected review
ports with the real curl-backed provider transport from rung 10 — plus
the four real-path defects the first live use surfaced in the rung-10
model transport and the rung-6 review prompt.

## Decision

1. The reviewer file follows the pins/verdict-file precedent: an
   operator-produced file admitted explicitly, parsed strictly (the five
   closed keys; unknown, duplicate, missing, empty, or non-integer fields
   refuse; a missing file or token file refuses `cannot read reviewer
   file`, a malformed file `malformed reviewer file`, both exit 2 before
   any run or transport work). The provider token is read from its
   mode-600 token-file and reaches only the one curl Authorization header;
   it never enters the prompt, a result, or the store.
2. `make-model-transports` now actually works against a real
   OpenAI-compatible server — three latent defects fixed (all
   fixture-invisible until the first real call):
   - `:input` passed the request body as a bare string, which UIOP
     treats as a *filename*; stdin now receives a string input stream.
   - The request envelope is a chat-completions message with
     `enable_thinking:false` (documented `[x-unsloth]` control; per-model
     support, harmless where unsupported) instead of a completions-style
     `prompt`, so the completion document is the answer rather than a
     reasoning trace.
   - The transport now extracts the model's completion document from the
     provider response envelope (first choice's `text` or
     `message.content`) via the model adapter's own minimal JSON scanner
     (numbers, booleans, and nulls consumed opaquely — the review
     reader's refusal of them is the rung-6 output contract and stays);
     an unparseable or oversized response maps to a nonzero exit so the
     caller's `:unverifiable` fact applies. The previous oversized path
     returned a NIL stdout, which the closed validation turned into a
     transport-fault instead of the documented mapping.
3. The rung-6 fixed review prompt was a bare JSON envelope — a strong
   fixture reviewer inferred the task, but real local models respond to
   it with clarification requests. The prompt now carries an explicit
   advisory-reviewer instruction with the exact output contract; the
   output schema and every prompt field are unchanged.

## Evidence

- `make test` green: 8 reader guards and 2,693 checks (baseline 2,616 +
  30 new: reviewer-file admission, envelope extraction, chat envelope).
- Live end-to-end proof against the operator's local Unsloth Studio
  server (OpenAPI 2026.8.19; llama-server OpenAI dialect; `model` is
  informational — the server auto-activates the named model; auth via
  the automation's auto-refreshed mode-600 token):
  - `scripts/hngh --store=<scratch> review run-1 content-hash=<sha256>
    paths=src/main.lisp reviewer=~/.hngh-automation/reviewer-local.conf`
    with `model=unsloth/Ornith-1.0-35B-GGUF` → `review status=complete
    findings=0` exit 0 with a `:current` review fact.
  - The same prompt directly: Ornith returns exactly the closed
    findings document, e.g. `{"findings":[{"label":"Potential unsafe
    model loading in adapter","citation":"src/adapter/model.lisp"},
    {"label":"Core logic lacks explicit fail-closed guard","citation":
    "src/main.lisp"}]}` — advisory metadata-level findings, as designed.
  - Model selection basis: the 2026-08-25 fleet bench
    (hngh-automation `stats/model-bench-2026-08-25.jsonl`) — Ornith-1.0
    (35B and 9B), AgentWorld-35B-A3B, and bartowski/Qwen3.8-27B scored
    perfect on coding/review-shaped probes; both gemma-4-12B variants
    missed the subtle defect; the server's MiniMax-H3 failed outright.

## Remaining unknowns

- Reviewer findings are advisory metadata-level reviews: the reviewer
  sees the content hash, paths, and policy labels, never file bytes.
  Feeding candidate content into the review is future work.
- No policy profile consumes review facts yet (the standing policy-profile
  gap).
- Per-model thinking behavior varies; the envelope pins
  `enable_thinking:false` which supported models honor and others ignore.
