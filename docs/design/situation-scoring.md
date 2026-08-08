# L2/L3 Situation Recognition & Scoring — Design Capture

**Status**: Design capture (2026-08-07/08). Requirements + architecture for the
auto-steering "brain" behind the A3 actuator (`acp-steer-command`,
`acp-steer`).
**Cross-links**: `agent-client-protocol.md` (A3 steering surface, §8),
`live-orchestration.md` (steering/observe layer), `sentry.lisp` (Tier-0
procedural watchers → these feed L2), `autonomy-strategy.md` (self-improving
loop), `cost-conservation.md` (judge model = cheap/local).

> Naming note: the roadmap's L1–L5 (live-orchestration.md) use "L2 =
> procedural guard-rails, L3 = steering primitive." This doc uses **L2 = situation
> RECOGNITION** (what is happening, which failure mode) and **L3 = SCORING**
> (how urgent/wide/impactful, what action). They are orthogonal axes — this
> doc is the recognition+scoring side that feeds the roadmap's L3 steering
> primitive. Do not conflate.

---

## 0. Purpose and the core principle

Hngh watches coding agents (Hermes, OpenCode) mid-turn and decides when to
intervene. The A3 actuator already exists: `acp-steer-command(score)` →
`:none` / `:steer` / `:interrupt`, and `acp-steer` applies it over ACP. What
missing is the *brain that produces a trustworthy score* from the observation
stream. This doc specifies that brain.

**Core principle (evidence-backed): agents can often recover their own
orientation.** Interrupting a working agent mid-turn is destructive and should
be rare. The scoring must model **recovery stage progression**, not isolated
faults, and escalate only on **convergent evidence** — multiple independent
flags or a fault recurring through its recovery stages without validation.

---

## 1. Grounding: the empirical /steer case-base (what humans actually steer for)

243 human `/steer` interventions were mined from `~/.hermes/.hermes_history`.
This is the single richest source of real steering signals. The recurring
situation classes, each with the human's actual trigger:

| Situation class | Real /steer triggers (paraphrased) | Count-ish |
|---|---|---|
| **Wasted waits / repeated expensive re-runs** | "How many times are you going to run make test?", "5 make tests in a row", "Don't you dare wait for more testing", "why are we waiting 600 seconds", "give it a meaningful wait time" | very high |
| **Faulty logic / inefficiency** | "That's very faulty logic", "guard against foolish choices", "don't get locked in to thinking that forces bad behavior", "why are we running the retry?" | high |
| **Not sourcing needed info** | "Why don't you search for the documentation?", "search for the documentation", "no guessing, read docs and search for verifiable info", "give yourself breadcrumbs, trace the error", "check the environment" | high |
| **Risky experiment instead of documented component** | "Don't guess or rationalize, use documentation", "don't just experiment, read documentation", "we don't need to reinvent things or waste tokens on things we've made progress on" | high |
| **Coordination gap (one agent knows what another needs)** | "Opencode is proceeding, check on its progress and coordinate", "you can coordinate with an opencode instance", "Remember not to step on our subagents' toes", "all our roles left breadcrumbs" | medium |
| **Cost / token overrun** | "We're spending a lot", "don't kill too many tokens", "openrouter's down to <$33", "condense into compact token sets for cheaper models" | medium |
| **Stuck / wedged seat / no progress** | "none of them are moving, no prompts put in", "an opencode just sitting stationary", "we lost the coder (again)", "failure to proceed" | high |
| **Model-identity / garbled fact error** | "any mention of 'gpt 3.6 luna' should be corrected to 'gpt 5.6 luna'" | low |
| **Out-of-scope / architectural overreach** | "make sure it isn't trying to make architectural changes", "catch folks who get out-of-line" | medium |

**Observation:** the overwhelming majority of human /steer messages target
**efficiency and grounding failures** (wasted waits, faulty logic, not
reading docs/state) — not safety catastrophes. This confirms the "steer, don't
interrupt" bias: most situations are correctable with a nudge that re-orients
the agent toward a cheaper/safer path, not with a halt.

---

## 2. L2 — Situation recognition (what is happening)

L2 names the situation from the observation stream. It produces a **situation
datum**: `{category, confidence, stage, evidence}`. Two detection tiers:

### 2.1 Tier-0: procedural detectors (deterministic, model-free, fail-closed)

Already the shape of `sentry.lisp` — no model in the hot path, regex/stdlib
only, always-on. These are cheap, never hallucinate, and provide the
**firmest evidence**.

| Detector | Signals (from research + /steer) | Provenance |
|---|---|---|
| **Identical-call loop** | same tool+args+error ≥3×; ping-pong A-B-A-B; cycle A-B-C-A-B-C | OpenFang #481, Strands |
| **Retry-without-progress** | args change cosmetically, error class unchanged, no new approach, ≥2 consecutive | AgentCenter, meritshot |
| **Zero-progress-delta** | sub-goal/artifact list unchanged across ≥2 steps despite actions | meritshot |
| **Long-thinking token sink** | long CoT / no tool call / no file mutation / task not advanced; plan restated 2+× | research (CoALA; Qwen3 56.8%) |
| **Repeated failing verification** | test/build re-run unchanged, or re-run with no relevant diff | /steer ("5 make tests") |
| **Excessive waits / idle** | N≥3 sleeps or idle > budget with zero output | /steer ("600 seconds", "meaningful wait") |
| **Context bloat / compaction storm** | token trend, repeated auto-compaction | research |
| **Cost-exceedance** | per-role/global budget crossed mid-run; remote quota/balance exhausted | cost-conservation, /steer |
| **Chatter-loops between agents** | cross-agent message ping-pong with no artifact progress | MAST FM-1.3/2.x sibling |
| **Fingerprint hash method** | `SHA256(tool+args)` sliding window; exempt polling tools | OpenFang (§4 prior art) |

### 2.2 Tier-1: model judge (semantic, on the acting + thinking stream)

Procedural detectors can't see *faulty logic that looks productive*, *hallucination*,
*instruction misinterpretation*, or *risky-approach-vs-documented-component*.
Those need a **judge model** over the transcript — but run on a **cheap/local**
model per cost-conservation, with **explicit confidence calibration** (novel
ground, see §6). The judge consumes a *bounded* window (recent N tool calls +
the current/nearby thought + last message), not the whole transcript (bounded
prompt, like `consolidate.py`'s KNOWLEDGE_BUDGET principle).

Judges map the six target situations + MAST's validated taxonomy:

| Target situation | Judge question (yes/no-ish, scored) | Primary input |
|---|---|---|
| 1. Faulty logic / wasted thinking | Is the current plan logically sound given observed state? Is the agent re-deriving a dead end? | thought stream + last action |
| 2. Risky experiment vs. documented component | Is the agent hand-rolling something a known CLI/lib covers (and is there a documented/prior-art path it skipped)? | acting stream + prior-art index |
| 3. Needs info, fails to source | Did the thought express "I need X" with no retrieval call within N steps? | thought + acting (mismatch) |
| 4. Needs info another agent has | Is the answer available in a sibling agent's output/state? (cross-agent) | sibling state, orchestration log |
| 5. Instruction misinterpretation | Does this action violate an explicit user constraint? | instruction context + action |
| 6. Hallucination (recognizable) | Is any assertion/result unbacked by a tool call in the stream? | acting stream cross-check |

**Thinking vs. acting — the load-bearing distinction (research §D):**
- **Thinking** (CoT, self-correction language, "I need X", plans) is
  **self-conditioned and unverifiable**. LLMs cannot reliably judge their own
  reasoning (Huang et al., Kamoi et al.). "I made a mistake, let me redo" is
  **not** evidence of recovery.
- **Acting** (tool calls, returned observations, file diffs, test results) is
  **environment-grounded and checkable**.
- **Rule: detectors weight the ACTING stream over the THINKING stream.** A
  recovery is only real when a *changed, validated action* follows — never when
  the thought trace merely asserts one. (This directly answers the user's
  thinking-vs-saying distinction.)

---

## 3. L3 — Scoring (how urgent, what action, at what stage)

L3 turns situation data into a score and an action, and — critically —
**lowers the bar on repeated/convergent evidence** (progressive gate-lowering).

### 3.1 The score

Reuse the existing `impact × urgency × spread` rubric (live-orchestration §3;
ACP §4) for **priority**, and add a **confidence** term from detector firmness:

```
score = w_i * impact * urgency * spread   (priority: who needs it now)
  +    w_c * confidence                    (how sure we are it's really this)
```

- **impact** (S1/S2/S3): wasted tokens · wrong-but-correctable · destructive/silent-wrong/policy-violation.
- **urgency**: how much work does ignoring it let continue to compound.
- **spread**: how many members/sessions are affected (coordination facts spread wide = high).
- **confidence**: Tier-0 (deterministic) = high; Tier-1 judge = its stated confidence, which must be calibrated (see §6).

Reuse `acp-steer-command`'s existing thresholds (steer ≥0.6, interrupt ≥0.9)
as *defaults* — but L3 may **lower them** via the recurrence multiplier (§3.3).

### 3.2 Recovery-stage model — the heart of "don't interrupt early"

Do NOT score a single fault. Score **stage progression** (research §B.4):

| Stage | Meaning | Detector implication |
|---|---|---|
| 1. Fault introduced | bad call / wrong assumption / hallucinated claim | record it |
| 2. Agent notices | triggered by an *external* observation (error, test fail, tool return) | tool-grounded faults self-notified; reasoning faults are NOT (self-judgment fails) |
| 3. Agent attempts correction | next call differs consistent with error (healthy) vs identical/cosmetic (unhealthy) | distinguish healthy vs unhealthy correction |
| 4. Correction validated | a subsequent observation confirms progress (test passes, error gone) | only this proves recovery |

**Escalation rule (evidence-derived):** escalate when
- (a) a fault persists through stages 2–3 **without validation** for **2 consecutive cycles**, or
- (b) the fault class is **S3** (hallucination that recurs, policy violation, irreversible/destructive action, instruction-misread beyond correction), or
- (c) **long thinking-run with zero environment interaction** (can't self-check — highest-risk pattern).

**Do NOT escalate** on: a single tool-level fault with a visible fix attempt
(error → changed args → retry), a one-off ungrounded claim, a missing-info
situation you can just point at. These are **steer** (or even just log), never
interrupt.

### 3.3 Progressive gate-lowering (repeat escalates action)

Each consecutive time the *same situation class* recurs within a window, the
action escalates one rung of the ladder (borrowed from prior art, novel for a
live agent):

```
log → steer → rewrite-pending-action → ask (HITL) → cancel-and-reprompt
```

- Same-class single fault with healthy correction → **log**.
- Same-class fault, unvalidated ×1, correctable by guidance → **steer**.
- Same-class fault, unvalidated ×2 → **steer with stronger/re-directed guidance**
  (or ask if high impact).
- Recurring same-class across contexts/agents → **interrupt and re-design**
  (MAST: repeated prompt-nudging has diminishing returns; reliability is the
  hard problem).

### 3.4 Steer-vs-interrupt final guidance (from research §D.4 and §B.3)

| Condition | Action |
|---|---|
| Missing info (target 3) | **steer** — point at the retrieval call / sibling state |
| Risky approach (target 2) | **steer** — point at the documented component |
| One ungrounded claim (target 6, low sev) | **steer** — "verify against the stream / map claim to a call" |
| Single tool fault with visible fix | **none / log** — healthy self-correction via ground truth |
| 2+ consecutive unvalidated same-class faults | **interrupt** |
| S3: policy violation / irreversible / credential leak / instr-misread | **interrupt** (gate) |
| Hallucination recurs after one steer | **interrupt** |
| Token sink, zero env interaction | **interrupt** |
| Coordination deadlock (target 4) | **interrupt + reprompt with sibling context** (cheaper than steering) |
| Cross-agent fact a squad needs now | **steer to all** (spread=high) — the "new squad-wide fact" case |

---

## 4. Six target situations → verified coverage matrix

| # | Situation | Tier-0 proc | Tier-1 judge | Interrupt-worthy? |
|---|---|---|---|---|
| 1 | Faulty logic → wasted thinking/tokens/time | token-sink, zero-progress | logic-soundness judge | only if recurs ×2 unvalidated (S2) |
| 2 | Risky experiment vs documented component | — | approach-choice judge + prior-art index | rare (S2, steer usually fixes) |
| 3 | Needs info, fails to source | — | "I need X"→no-call mismatch | no — always steer |
| 4 | Needs info another agent has | chatter-loop | cross-agent state match | steer-to-all first; interrupt iff deadlock |
| 5 | Instruction misinterpretation beyond correctable | constraint-violation | instruction-conformance judge | YES — S3 |
| 6 | Recognizable hallucination | forged-result / unbacked-claim | claim↔call cross-check | recur-after-steer → YES |

---

## 5. Action channel (reuse A3, no new wire)

All actions apply through the already-shipped A3 actuator over ACP:
- **steer** → `acp-steer` `:steer` → `session/prompt` with the guidance payload.
- **interrupt** → `acp-steer` `:interrupt` → `session/cancel` + reprompt.
- **ask / record-verdict** → `session/request_permission` (human-gate) + ledger.

Guidance payloads are **steer-shaped prompts**: point at the missing action /
component / sibling state, never "you're wrong" (research: content of feedback
matters more than its source — a weak local model's steer helps, MINT).

---

## 6. Judge model & guardrails (cost + calibration)

Per cost-conservation, the mid-turn judge is a **cheap/local** model, NOT a
frontier reserve model:
- **Judge** role → deepseek-v4-flash-class (or local). It produces a **score +
  one-line why + confidence**. This is novel ground (published judges are
  frontier/offline) and must be **calibrated**, not trusted:
  - Run the judge **offline against the case-base** (the 6 situations + labeled
    /steer history) to measure precision/recall and confidence calibration
    before trusting it live (§7 improvement loop).
  - Tie it to a **watchdog budget**: bounded judge calls per run, only on
    *suspicious windows* (Tier-0 raised a soft flag first), never on every step
    (cost: cheap model + sparse invocation keeps this negligible).
  - **Fail-closed**: low-confidence judge output → treat as lower-tier action,
    never escalate.
- Tier-0 is the priority: it's free, deterministic, and catches the 
  highest-count real situations (loops, wasted waits, token sinks). Build it
  first.

---

## 7. Self-improving recognition loop (the "knowledge is power" requirement)

The system must **improve its own recognition** over time, sourcing from its
own work and the web:

1. **Case-base (primary)**: every scored situation + action + outcome is
   appended to the case-base, alongside the human /steer interventions (the
   ground truth of what a human judged worth fixing). This is the training
   signal for recalibration.
2. **Regular review pass** (cheap/local, scheduled): periodically re-run the
   judge offline against the growing case-base to (a) recalibrate confidence,
   (b) tune thresholds, (c) discover *new* situation classes emerging in recent
   work — the taxonomy is **open, not frozen**.
3. **Sourcing from the web**: the taxonomy and detector set are re-grounded
   against current research (MAST, tau-bench, hallucination benchmarks) on a
   schedule; new validated failure modes get detectors. (We are explicitly
   allowed to source this; Hngh continues to.)
4. **Attribution ledger**: every decision + its evidence + the model/version
   that made it is logged (user's rigorous-attribution requirement); used for
   auditing and for the review pass.
5. **Human-feedback loop**: when a human /steers (or overrides an auto-action),
   that becomes the highest-weight case-base entry — the system learns what
   humans actually value steering for, closing the loop.

---

## 8. Build order (least-first, verification-gated)

| Step | Scope | Gate |
|---|---|---|
| **1** | Tier-0 procedural detectors (loop, zero-progress, token-sink, waits, cost, chatter) on the sentry/observation stream | unit tests on synthetic + replay of real /steer-derived fixtures; no model calls |
| **2** | Situation datum + L3 scoring (impact×urgency×spread×confidence) + stage-tracker | unit tests; recovery-stage logic verified against labeled cases |
| **3** | Progressive gate-lowering + steer/interrupt mapping → A3 actuator | integration tests with the ACP mock + real steer applied to fixtures |
| **4** | Judge model (cheap/local) on suspicious windows; bounded, fail-closed | offline calibration against case-base before live |
| **5** | Case-base + review pass + web re-grounding (self-improvement loop) | calibration metrics improve over successive passes |
| **6** | Cross-agent normalization (Hermes + OpenCode traces same scorer) | dogfood on live squads |

---

## 9. Sources & prior art (consolidated)

- **Empirical case-base**: 243 `/steer` messages from `~/.hermes/.hermes_history`.
- **Research reference**: `agent_failure_modes_reference.md` (~32KB, 23 sources)
  — arXiv Huang/Kamoi/MINT/ReAct/SWE-agent/GAIA/MAST/tau-bench/CoALA, hallucination
  benchmarks (SelfCheckGPT, MIRAGE, SimpleToolHalluBench, AgentHallu, StableToolBench,
  ToolBeHonest), Anthropic Building Effective Agents. Saved at
  `~/Projects/etc/sysconfig_mgmt/agent_failure_modes_reference.md`.
- **Prior-art design space**: `B1_agent_supervision_design_space.md` (~24KB, 30+
  sources) — guardrails (LlamaGuard, NeMo, Guardrails AI, AGT), observability
  (OTel GenAI), self-verification (PRM, CriticGPT, Reflexion, LATS), stuck-detection
  (OpenFang #481, strands, AgentCenter), HITL (LangGraph, Claude Code hooks). Saved
  at `~/Projects/etc/sysconfig_mgmt/B1_agent_supervision_design_space.md`.
- See the two reference docs for full bibliographies; the key headline findings
  are inlined in §B.1–B.4 and §4 of the research reference.

---

## 10. Explicit gaps (novel ground we own)

1. **Live, progressive-gate-lowered scoring** on a running agent (ingredients
   exist separately; the combination is unclaimed).
2. **A "stuckness/progress" metric** — no standard semantics (OTel has no
   progress attr); Hngh defines it.
3. **Live false-completion gate** ("done" claims verified against test/git
   state mid-run).
4. **Per-step process scoring over tool-call trajectories** for *code* agents.
5. **Cross-agent normalization** (Hermes + OpenCode, one scorer).
6. **Weak local model as a calibrated realtime mid-turn judge.**

## Attribution
Design capture for Hngh (owner brief: L2/L3 situation recognition + scoring
for auto-steering). Research delegated to deepseek-v4-flash subagents; /steer
case-base mined from ~/.hermes/.hermes_history; synthesized by
deepseek-v4-flash-0731 via openrouter (Hermes TUI).
