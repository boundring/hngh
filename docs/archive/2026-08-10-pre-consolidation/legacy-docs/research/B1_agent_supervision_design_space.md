# B1: Design Space — Agent Supervision, Monitoring & Intervention

**Purpose:** Borrow-list for Hngh L2/L3 situation-scoring + gate-lowered steering
(monitors Hermes/OpenCode coding agents; decides steer-guidance vs
cancel-and-reprompt). Companion to B0/PRIOR_ART_BRIEF; same conventions:
per-system *detects / signal / action / borrow*, prioritized borrow table,
explicit gaps. Verified via web fetch 2026-08-08; URLs per claim.

**Hngh context this maps onto** (from hngh skill): Tier-0 `sentry` procedural
watchers (regex/stdlib, fail-closed, no model calls), `threat.flag` events with
`:layer :L3`, `llm-threat-detector` observing flags offline, ACP client with a
**steer-vs-interrupt** negotiation pattern, `:authority` (:advisory / :worker)
on tasks, "human owns every mutation".

---

## 0. Action taxonomy used throughout (unify vocabulary)

Prior art's intervention verbs, from weakest to strongest:

`log → alert → steer (inject guidance into context) → rewrite (mutate the
pending action) → ask (HITL gate) → block/deny (one action) → halt/abort (run)
→ tripwire-raise (exception) → rollback (undo applied work) → cancel-and-reprompt`

Plus *escalation ladders* (warn→suggest→block; ask→deny; steer→interrupt).
Hngh's steer-vs-interrupt is the two top rungs; everything below "steer" is the
unexplored middle (see Gaps §8).

---

## 1. Guardrails frameworks — content/action risk classification & scoring

| System | Detects | Signal | Action | Borrow |
|---|---|---|---|---|
| **Llama Guard** (Inan et al., arXiv 2312.06674) | Unsafe input/output on a 13-category taxonomy (violence, sexual, PII…) | Classifier output: `safe`/`unsafe` + category labels (binary, not scored) | Log/flag only — classifies but does not enforce | Taxonomy-driven classification is the right shape for situation categories |
| **NVIDIA NeMo Guardrails** (Rebedea et al., EMNLP 2023 demo; github.com/NVIDIA-NeMo/Guardrails) | Jailbreaks, off-topic, unsafe output, retrieval grounding, dialog-flow violations | Programmable Colang rails (input/output/topic/retrieval/jailbreak rails), canonical-form extraction, per-rail enforcement | Block + set intent + **re-prompt/generate** (self-correct), steer conversation back on-rail; eval via LLM-as-judge "policy compliance rate" (developer.nvidia.com/blog measuring guardrails) | Rail-per-risk-type separation; **re-prompt = steer** is the proven corrective primitive; LLM-judge for offline rail effectiveness |
| **Guardrails AI** (guardrailsai.com/docs) | Output violating declared constraints (type, PII, quality, tone) | Validators return pass/fail + metadata | **OnFail actions: exception / fix / filter / refine / reask / noop** — `fix` rewrites the output, `reask` re-prompts the LLM (up to N times) | The on-fail action menu is exactly the intervention menu Hngh needs per situation; reask-with-cap maps to cancel-and-reprompt |
| **OpenAI Moderation API** (platform.openai.com/docs/guides/moderation) | Harm categories in text | **Continuous per-category scores** (not binary) | Threshold-gated block/flag; scores can drive graded policy | Continuous severity scores instead of binary — model for calibrated L1/L2/L3 scores |
| **Azure AI Content Safety** (learn.microsoft.com/azure/ai-services/content-safety) | Hate/self-harm/sexual/violence | **Severity levels: safe / low / medium / high** per category | Different policy per severity band (e.g. med=block, low=flag) | Severity-band → action mapping is a direct precedent for "score crosses tier ⇒ escalate action" |
| **Constitutional AI** (Bai et al., arXiv 2212.08073) | Output violating principles | Critic model critique | **Critique → revision** loop (self-critique then revise), RLAIF training | The critique-then-revise loop is the canonical self-steering architecture; critique must be *actionable* |
| **Constitutional Classifiers** (Anthropic 2025, anthropic.com/research/constitutional-classifiers) | Jailbreak attempts at classification time | Classifier over input+output with constitution | Filter/block before harm | Classification-time filtering at the boundary is Tier-0-flavored: cheap, fail-closed |
| **Microsoft Agent Governance Toolkit (AGT)** (github.com/microsoft/agent-governance-toolkit; aka.ms/agent-governance-toolkit) | Runtime policy violations on *any* agent action | YAML policy evaluated per tool call; zero-trust identity; OWASP Agentic-AI risk mapping | `govern()` wrapper → logs decision every call, raises `GovernanceDenied`; middleware layer, not kernel | **"Agents ask. Platforms decide."** — Hngh is exactly this: middleware governance with decision logging; per-call policy evaluation + deny = Tier-0/L3 pattern |

**§1 takeaway:** guardrails maturely cover *content and action safety* with
scored, tiered, taxonomy-driven classification and a rich action menu
(reask/fix/refine/block). They do **not** look at trajectory health
(progress, stuckness, looping) — that axis is unclaimed.

---

## 2. Agent observability & tracing — what metrics exist

- **OpenTelemetry GenAI semantic conventions** (opentelemetry.io/docs/specs/semconv/gen-ai/; agentic extension tracked in github.com/open-telemetry/semantic-conventions-genai/issues/35): `gen_ai.*` attrs for model/token-usage/finish_reasons; **agent spans** (`create_agent`, `invoke_agent` with `gen_ai.agent.name`), tool/MCP spans (`mcp.method.name`), and opt-in **events like `gen_ai.evaluation.result` → `score.value=0.92, score.label="relevant"`** (example trace in greptime.com blog, 2026-05-09). *Signal:* latency, tokens, finish reasons, tool calls — **no "stuckness" or "progress" attribute exists.**
- **Datadog Agent Observability** (datadoghq.com/blog/llm-otel-semantic-convention/): maps semconv to native latency/token/cost/finish-reason metrics; `gen_ai.operation.name` (`tool_call`, `agent_run`) for end-to-end flow. *Action:* dashboards/alerts (post-hoc).
- **LangSmith / Langfuse** (docs.smith.langchain.com; docs.langfuse.com): traces, token usage, latency, run status, evaluators/feedback; Langfuse "scores" attach scalar ratings to traces. *Action:* log/alert only; no runtime intervention.
- **OpenInference (Arize Phoenix)** vs OTel GenAI (arthur.ai column): competing span schema; OpenInference has more granular span types for agent internals today.
- **MAST LLM-as-judge annotation** (arXiv 2503.13657): o1 annotator labels traces against a 14-mode failure taxonomy, κ=0.77 vs humans, validated on unseen frameworks κ=0.79 — *offline* classification of traces at scale.
- **AgentCenter operational playbook** (agentcenter.cloud/blogs/how-to-detect-agent-stuck-or-looping): task-level timeouts (2–5/10–15/30–60 min by task type), checkpoint markers, retry caps (2–3), token-budget staircase detection, 30s heartbeats with 60–90s stale alert. *Action:* alert/kill-and-log.

**§2 takeaway:** tracing gives raw material (per-step events, tokens, latency)
and even a score-event convention (`gen_ai.evaluation.result`) we can adopt
verbatim for Hngh's per-step situation scores — but everything is
**descriptive/post-hoc**. Nobody closes the loop from trace metrics to runtime
steering. "Emit scored events on the trace; let the policy layer act on them"
is a clean division Hngh can own.

---

## 3. Self-verification / self-consistency / process scoring

| Method | Detects | Signal | Action | Paper |
|---|---|---|---|---|
| **Self-Consistency** | Wrong/divergent reasoning | Sample N CoT paths, majority vote; **answer disagreement = low confidence** | Re-sample/trust majority; confidence signal | Wang et al., arXiv 2203.11171 |
| **Self-Refine** | Output defects | Self-feedback (same model critiques own output) | **Iterative generate→feedback→refine** (steer loop, no retraining) | Madaan et al., arXiv 2303.17651 |
| **Reflexion** | Task failure | Failure signal (tests, eval, self-check) | **Verbal reflection stored in episodic memory → retry with new plan**; 91% pass@1 HumanEval | Shinn et al., arXiv 2303.11366 |
| **CRITIC** | Incorrect/unverifiable output | LLM critic + **external tools** (interpreter, search) | Critique → revise against ground truth | Gou et al., arXiv 2302.12813 |
| **SelfCheckGPT** | Hallucination | **Sampling consistency** (N samples' agreement) | Flag/unanswer; consistency as proxy for factuality | Manakul et al., arXiv 2303.08896 |
| **Let's Verify Step by Step (PRM)** ⭐ | Wrong intermediate steps | **Per-step correctness labels (process supervision)**; PRM800K; PRM solves 78% of MATH subset | Score each step → guide search/reject bad steps; process > outcome supervision | Lightman et al., arXiv 2305.20050 |
| **Tree of Thoughts / LATS** | Dead-end states | LLM state-evaluation values; LATS = MCTS with learned **value functions over agent states** | **Prune/backtrack/explore**; state value drives search | Yao et al., arXiv 2305.10601; Zhou et al., arXiv 2310.04406 |
| **LLM-as-a-Judge** | Output quality | Judge model pairwise/pointwise scores with rubric | Rank/select; **rubric = interpretable scoring contract** | Zheng et al., arXiv 2306.05685 |
| **CriticGPT** | Bugs in model-written code | RLHF-trained critic model writes NL feedback; critiques preferred over human 63%; finds bugs in "flawless" data | Critique feeds RLHF labeling; **critic+worker separation** | McAleese et al., arXiv 2407.00215 |
| **Constitutional AI** | Principle violations | Critique model | Critique→revise (see §1) | Bai et al., arXiv 2212.08073 |

**§3 takeaway:** the closest existing thing to mid-turn situation scoring is
**process reward modeling** (score every step, not just the outcome) — but it
is trained for math, labeled post-hoc, and has no intervention channel. The
**critic model** (CriticGPT) is the architectural precedent for Hngh's L3
judge: a separate model whose output is natural-language feedback plus a
score, used to steer a worker. LATS proves LLM value functions over agent
states work. Reflexion proves **retry-with-reflection beats blind retry**.

---

## 4. Production coding agents: stuck/looping detection (closest prior art)

- **Hermes Agent today** (github.com/NousResearch/hermes-agent): hard `max_iterations` cap (default 60) in `run_agent.py`; nothing detects loops. **Issue #481** (March 2026) proposes a Loop Guard modeled on OpenFang; **issue #414** proposes iteration-budget pressure warnings. This is the in-house gap Hngh fills.
- **OpenFang loop guard** (RightNow-AI/openfang, `loop_guard.rs`; detailed in hermes issue #481): hashes each tool call as `SHA256(tool_name + serialized_args)`; sliding window; detects **exact repetition (3×), ping-pong A-B-A-B, cycles A-B-C-A-B-C**; **exempt-tools list** (polling); **escalation: warning message injected → backoff suggestion → hard block**. Configurable thresholds.
- **Strands hooks** (dev.to AWS series "How to Prevent AI Agent Reasoning Loops"): `BeforeToolCallEvent` debounce hook (window=3, ≥2 dupes ⇒ `cancel_tool` with "BLOCKED: Duplicate call detected"); `LimitToolCounts` per-tool budgets; insight: **agents loop when tools lack terminal SUCCESS/FAILED states**.
- **AgentCenter** (see §2): five detection signals — task timeout, checkpoint stall, retry count, token staircase, heartbeat.
- **Progress-delta detection** (meritshot.com/blog/ai-agent-looping-how-to-stop): **step limits ≠ progress detection**; detect *zero progress delta* (action taken but sub-goal list unchanged) over ≥2 steps ⇒ looping. Also: per-step duration vs average ⇒ stuck in sub-loop.
- **MAST failure taxonomy** ⭐ (arXiv 2503.13657; 1642 annotated traces, 7 frameworks): 41–86.7% failure rates. The trajectory-relevant modes, with prevalence: **FM-1.3 step repetitions 15.7%** (biggest single mode), **FM-2.6 reasoning-action mismatch 13.2%**, **FM-1.5 not recognizing task completion 12.4%**, **FM-3.3 incorrect verification 9.1%**, **FM-3.2 no/incomplete verification 8.2%**, FM-2.3 task derailment 7.4%, FM-2.2 wrong assumptions instead of clarifying 6.8%, FM-3.1 premature termination 6.2%. Interventions measured: better role specs +9.4% success; **adding a high-level objective-verification step +15.6%**; explicit verifiers reduce failures but "superficial checks" (compile-only) are the norm. → **These 14 modes are a ready-made situation taxonomy for L2/L3 scoring.**
- **Hard abort primitives**: LangGraph `recursion_limit` (default 25; langchain docs); OpenAI Agents SDK `max_turns` → `MaxTurnsExceeded` exception (openai.github.io/openai-agents-python/guardrails/).
- **Context management as stuck-adjacent**: Claude Code auto-compaction at context limits; `/rewind` for rollback to earlier checkpoint (code.claude.com/docs).
- **METR long-horizon studies** (metr.org/blog/2025-03-19-measuring-ai-ability-to-complete-long-tasks/; arXiv 2503.14499): models fail **silently** — often *claim completion without completing* (hallucinated task completion); time horizons (50%/80% success) doubled ~every 7 months. → False-done is a first-class failure mode to gate on.

**§4 takeaway:** fingerprint-based loop detection with warn→block escalation is
proven and cheap (Tier-0 shape). Token staircase, checkpoint stall, progress
delta, and false-completion are all detectable from existing Hermes/OpenCode
traces. MAST gives the *taxonomy*; nobody has turned it into a *runtime
scorer*.

---

## 5. Human-in-the-loop approval gates

- **Claude Code permissions + hooks** (code.claude.com/docs/en/permissions, /hooks): rule layer `allow/deny/ask` evaluated in order **deny → ask → allow**; `PreToolUse` hooks return `permissionDecision: allow|deny|ask|defer` + `permissionDecisionReason` (deny-reason shown to Claude, allow-reason to user) and can **rewrite arguments via `updatedInput`** (a steer-by-rewrite primitive); `PermissionRequest` hook decides on behalf of user; deny/ask rules always re-evaluated on top of hook output. Permission modes (default / acceptEdits / plan / bypassPermissions).
- **OpenAI Codex** (github.com/openai/codex; developers.openai.com/codex): approval modes **read-only / auto / full-auto / plan**; OS-level sandboxing; per-action approval prompts for risky commands.
- **LangGraph HITL** (docs.langchain.com/oss/python/langgraph/interrupts + human-in-the-loop): **dynamic `interrupt()`** anywhere in the graph vs static `interrupt_before/after` breakpoints; state persisted via checkpointer; resume via `Command(resume=...)`; **decision types: approve / edit / reject (with message to agent) / respond (answer becomes tool result)**; `update_state` allows **direct state correction / time travel** — a human (or supervisor) steering by editing state. `HumanInTheLoopMiddleware` lets you configure per-tool which decisions are allowed.
- **OpenAI Agents SDK** (openai.github.io/openai-agents-python/guardrails/): input/output/**tool** guardrails; guardrail failure raises **tripwire exception halting the run**; `max_turns` cap per run.
- **Coding-agent UX gates**: Cursor/Copilot ask-then-diff-review; Aider **architect mode** (a planning model proposes, an editor model applies — division of labor mirroring L2 planner vs L3 critic) plus auto lint/test-and-fix loops (tests as the progress signal).
- **Microsoft HITL guidance**: "Guidelines for Human-AI Interaction" (Amershi et al., CHI 2019) and Microsoft's human-in-the-loop guidance for agents — scope gates to consequential actions, give reasons, allow override.
- **AGT** (see §1): middleware decides autonomously per policy; human reviews decisions via audit log — **machine-in-the-loop first, human on exception**.

**§5 takeaway:** HITL gates are binary (ask/allow/deny) and human-dependent;
the valuable patterns are **conditional dynamic interrupts** (only when a
scorer trips), **decision menus incl. edit and respond**, **steer-by-rewrite
(`updatedInput`)**, **state correction (`update_state`)**, and **deny-reason
fed back to the agent**. "Machine decides routine, human decides exception"
(AGT) is exactly the Hngh autonomy model.

---

## 6. Progress-detection signal inventory (cross-cutting synthesis)

| Signal | Detection technique | Provenance | Action it enables |
|---|---|---|---|
| Identical repeated tool call | SHA-256 fingerprint + sliding window (≥3) | OpenFang, Strands, Hermes #481 | steer → block |
| Ping-pong / cycle A-B-A-B | pattern match over hash window | OpenFang | steer → block |
| Zero progress delta (sub-goals unchanged) | compare goal list across steps | meritshot, AgentCenter checkpoints | steer → cancel-and-reprompt |
| Token staircase (flat…jump…flat) | per-task token budget vs actual | AgentCenter | alert → abort |
| Checkpoint stall | checkpoint timestamps | AgentCenter | alert |
| Heartbeat loss | 30s heartbeat, 60–90s stale | AgentCenter | alert → abort |
| Task over-timeout | per-task-type timeout table | AgentCenter, LangGraph | abort |
| Per-step duration outliers | latency vs rolling average | meritshot | flag sub-loop |
| Error-rate escalation (same tool failing repeatedly) | retry counter per tool | AgentCenter (cap 2–3), Strands LimitToolCounts | steer w/ "read the error" |
| Reasoning-action mismatch | model judge over (last message, next tool) | MAST FM-2.6 | steer → ask |
| False completion ("done" but work unverified) | cross-check claims vs tests/git state | METR; MAST FM-3.x | ask → verify gate |
| Context bloat / compaction storm | token usage trend, compaction events | Claude Code | alert → steer to subdivide |
| Step repetition / not-recognizing-completion | trajectory classifier | MAST FM-1.3/1.5 (15.7%/12.4%) | steer → cancel-and-reprompt |

---

## 7. Prioritized borrow list for Hngh L2/L3

| P | Borrow | Source | Maps to Hngh |
|---|---|---|---|
| P0 | **MAST 14-mode failure taxonomy as the situation-class vocabulary** (esp. FM-1.3, 1.5, 2.6, 3.1–3.3) | arXiv 2503.13657 | L2 situation categories; scoring rubric text |
| P0 | **Escalation ladder warn → suggest → block**, with injectable guidance messages and configurable thresholds | OpenFang loop_guard | gate-lowered steering core; steer-vs-interrupt channel (ACP) |
| P0 | **Fingerprint loop detection (hash+sliding window) + exempt-tools list** | OpenFang, Strands, Hermes #481 | Tier-0 sentry addition (procedural, model-free) |
| P0 | **Process-reward-style per-step scoring** (score the step, not just the final answer) | Lightman 2305.20050 | L3 model judge emits per-step score + NL critique (CriticGPT-style) |
| P0 | **`gen_ai.evaluation.result` score events on the trace** | OTel GenAI semconv | publish score events per step; observability-native |
| P1 | **Severity bands → action mapping** (safe/low/med/high ⇒ different action) | Azure Content Safety, OpenAI Moderation | L1/L2/L3 thresholds |
| P1 | **OnFail action menu** (reask w/ cap, fix/rewrite, refine, block) | Guardrails AI | intervention menu per situation |
| P1 | **Approve/edit/reject/respond decision types + deny-reason fed to agent** | LangGraph, Claude Code hooks | human-ask tier of the ladder |
| P1 | **Steer-by-rewrite of the pending action** (`updatedInput`; `update_state`) | Claude Code hooks, LangGraph | steer tier implementation |
| P1 | **Checkpoints + token staircase + heartbeat + per-task timeouts** | AgentCenter | Tier-0 progress signals |
| P1 | **False-completion gate: verify "done" claims against tests/git** | METR, MAST FM-3 | L3 verify-before-done |
| P2 | **Reflexion-style retry-with-reflection** instead of blind retry | Shinn 2303.11366 | cancel-and-reprompt payload design |
| P2 | **LLM-as-judge with explicit rubric** (interpretable, calibrated) | Zheng 2306.05685; MAST annotator (κ=0.77) | judge prompt contract; eval of judge |
| P2 | **Decision logging on every scored action** (audit trail) | AGT, Claude Code hooks | threat.flag/event-bus records |
| P2 | **Conditional dynamic interrupts only on tripped conditions** | LangGraph interrupt() | keep low-stakes runs friction-free |

---

## 8. Gaps — novel ground (no prior art found)

1. **Mid-turn, calibrated situation scoring with a progressive gate-lowered
   intervention ladder** (log → steer → rewrite → ask → cancel-and-reprompt,
   thresholds *lowering per repeat*). Each ingredient exists separately
   (OpenFang binary warn/block; guardrails content-scoring; PRM offline math
   scoring; MAST offline taxonomy; HITL binary gates) — **no published system
   combines continuous trajectory scoring with a scored escalation ladder in
   real time on a live agent.**
2. **A "stuckness/progress" metric has no standard semantics** — OTel GenAI
   semconv has token/latency/finish_reasons and now score events, but no
   progress or stuckness attribute; Hngh would define it.
3. **Live false-completion detection.** METR documents silent
   claim-done-without-done post-hoc; no coding agent gates "I'm done" against
   verifiable state mid-run. Hngh's verify-before-done is unclaimed.
4. **Process scoring for *code* agents.** PRMs are math-trained; CriticGPT
   reviews code but post-hoc and not per-step; no per-step process reward
   model over tool-call trajectories exists in production.
5. **Cross-agent normalization** (same scoring over Hermes AND OpenCode
   traces). Observability vendors are trace-format-specific; Hngh sits above
   both.
6. **Weak local model as hot-path mid-turn judge with confidence
   calibration.** Published judges are frontier models used offline
   (MAST uses o1; CriticGPT is a fine-tune). Running a cheap local model
   (hngh's pattern: model for offline analysis) as a *realtime* scorer with
   explicit confidence thresholds is untrodden.

---

## Sources

- MAST: Cemri et al., "Why Do Multi-Agent LLM Systems Fail?" — arxiv.org/abs/2503.13657; github.com/multi-agent-systems-failure-taxonomy/MAST
- OpenFang loop guard: github.com/RightNow-AI/openfang (`openfang-runtime/src/loop_guard.rs`), via github.com/NousResearch/hermes-agent/issues/481
- Hermes issues: #481 (Tool-Call Loop Guard), #414 (Iteration Budget Pressure) — github.com/NousResearch/hermes-agent
- Strands debounce hooks: dev.to/aws/how-to-prevent-ai-agent-reasoning-loops-from-wasting-tokens-2652
- AgentCenter: agentcenter.cloud/blogs/how-to-detect-agent-stuck-or-looping
- Meritshot progress-delta: meritshot.com/blog/ai-agent-looping-how-to-stop
- Llama Guard: arxiv.org/abs/2312.06674
- NeMo Guardrails: aclanthology.org/2023.emnlp-demo.40; github.com/NVIDIA-NeMo/Guardrails; developer.nvidia.com/blog/measuring-the-effectiveness-and-performance-of-ai-guardrails-in-generative-ai-applications/
- Guardrails AI: guardrailsai.com/docs (validators, on-fail actions); arxiv.org/html/2402.01822v1 (comparison Llama Guard/NeMo/Guardrails AI)
- OpenAI Moderation: platform.openai.com/docs/guides/moderation
- Azure Content Safety severity: learn.microsoft.com/azure/ai-services/content-safety
- Constitutional AI: arxiv.org/abs/2212.08073; Constitutional Classifiers: anthropic.com/research/constitutional-classifiers
- Microsoft AGT: github.com/microsoft/agent-governance-toolkit; aka.ms/agent-governance-toolkit; opensource.microsoft.com/blog/2026/04/02/introducing-the-agent-governance-toolkit-open-source-runtime-security-for-ai-agents/
- OTel GenAI semconv: opentelemetry.io/docs/specs/semconv/gen-ai/; github.com/open-telemetry/semantic-conventions-genai/issues/35; greptime.com/blogs/2026-05-09-opentelemetry-genai-semantic-conventions; arthurai.com/column/openinference-vs-opentelemetry-genai-conventions-agent-tracing
- Datadog Agent Observability: datadoghq.com/blog/llm-otel-semantic-convention/
- LangSmith: docs.smith.langchain.com · Langfuse: docs.langfuse.com
- Self-Consistency: arxiv.org/abs/2203.11171 · Self-Refine: arxiv.org/abs/2303.17651 · Reflexion: arxiv.org/abs/2303.11366 · CRITIC: arxiv.org/abs/2302.12813 · SelfCheckGPT: arxiv.org/abs/2303.08896 · Let's Verify Step by Step: arxiv.org/abs/2305.20050 · ToT: arxiv.org/abs/2305.10601 · LATS: arxiv.org/abs/2310.04406 · LLM-as-judge: arxiv.org/abs/2306.05685 · CriticGPT: arxiv.org/abs/2407.00215
- Claude Code permissions/hooks: code.claude.com/docs/en/permissions; code.claude.com/docs/en/hooks
- Codex: github.com/openai/codex; developers.openai.com/codex
- LangGraph HITL/interrupts: docs.langchain.com/oss/python/langgraph/interrupts; docs.langchain.com/oss/python/langchain/human-in-the-loop
- OpenAI Agents SDK guardrails/tripwires: openai.github.io/openai-agents-python/guardrails/
- METR: metr.org/blog/2025-03-19-measuring-ai-ability-to-complete-long-tasks/; arxiv.org/abs/2503.14499
- Amershi et al., Guidelines for Human-AI Interaction: CHI 2019
- OpenAI harness engineering: openai.com/index/harness-engineering/; Anthropic–OpenAI pilot supervision eval: openai.com/index/openai-anthropic-safety-evaluation/
