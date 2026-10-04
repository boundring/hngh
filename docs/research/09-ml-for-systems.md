---
category: ml-for-systems
persona: The Augur
status: seed
---

# ML for Systems — what hngh runs today

hngh uses models in three disciplined lanes: bounded review, editorial decoration, and typed arbitration — never as uncertified truth. **Model transport** is closed and minimal: `src/adapter/model.lisp` builds one fixed provider envelope (a chat-completions message with the review prompt as the sole user turn, "thinking disabled so the completion document is the answer rather than a reasoning trace"; src/adapter/model.lisp:40-44), parses responses with its own envelope scanner (:165-171), and `make-model-transports` validates a closed provider config (endpoint, model-name, max-tokens, timeout, provider-token; :196-199). Routing is a fallback chain — lib/model.sh: unsloth → budgeted remote → ollama → archive, with a `model_call` port and `MODEL_USED` receipt (docs/design/subsystem-anatomy.md:24) — with per-leg pacing caps in cadence-params.tsv (`xiaomi-cap-day 40`, automation/cadence-params.tsv:73).

**Editorial persona lane** (`automation/lib/ghost-voices.py`): a ghost pantheon from `config/ghost-voices.tsv` blended three-at-a-time — deterministic sha1-seeded sampling (:67-73) — asking Xiaomi MiMo for one-shot counsel. The contract is explicit: "Decoration, not data: every failure path returns None" (:2-10); counsel containing stale-machine-state mentions is discarded — "counsel must not invent machine facts it cannot see" (:136-137). The article-summary lane is batched ONE call per compose with a 7-day cache and a 12/day cap (`ghost-cap-day`; :144-153,220-249).

**Procedural verdict logic** stays model-free where correctness matters: `jobs/dashboard-self-review.py:2-27` derives sufficient vs insufficient dashboard state procedurally (freshness/validity/served/ledger) and classifies into `unacceptable-now` / `acceptable-for-now`; the readout spine's `verdict` key is computed, not generated (automation/cadence/subhour/05-readout.sh:14-24). Where models do judge, verdicts are structured and grounded: the research beat demands supportive + adversarial passes plus exactly one `VERDICT: adopted|parked|killed` line (automation/cadence/hour/33-research-beat.sh:900-1003), and an ADOPTED verdict must cite a specific evidence item — file path with extension or :line — in the supportive pass (ground-truth gate; :766-769). Typed arbitration is monotone: a typed answer can raise a legacy severity, never lower it, at confidence floors 0.60/0.5 (automation/CHANGELOG.md:415-419); Jev ordering advice is bounded — "Jev advises, never certifies" (automation/cadence-params.tsv:80).

## Open questions for web research

1. LLM-as-judge calibration: setting confidence floors and monotone arbitration between two verdict sources — evaluation-harness precedents.
2. Grounding guards against hallucinated machine facts (STALE_MENTION_RE class) — fact-check or citation-required prompting patterns.
3. Deterministic persona blending (seeded sampling) for editorial voice — controlled generation precedents.
4. Structured typed-classification seams vs freeform parse-and-regex verdict extraction — robustness tradeoffs.
5. Model fallback chains and cost pacing across local + quota legs — routing/circuit-breaker designs for inference fleets.

## Candidate external systems to survey

- DSPy
- NeMo Guardrails
- Guardrails AI
- promptfoo (verdict + eval loops)
- Braintrust / LM evaluation harnesses
