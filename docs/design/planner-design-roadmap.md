# Planner Design & Roadmap Depth — Planning, Design, Scheduling, Dispatch, Feedback

**Status**: Design companion to the C6 planner build plan (2026-08-07).
**Location**: cross-links `squad-autonomy.md` §8 (C6), `squad-startup-automation.md`
§9 (waves), `squad-metabolism.md` (senses/retrospectives), `model-pareto.md`
(scaffold optimization), `autonomy-strategy.md` (research). Source of
grounding: code inspection of the implemented queue/hngh-up/resource-gate
plus the "Self-Improvements in Modern Agentic Systems" survey (arxiv 2607.13104).

---

## 0. Purpose

The C6 build plan (`.hermes/plans/2026-08-07_141500-c6-recursive-planner.md`)
is the *how*. This doc is the *how far / how well*, answering four questions:

1. How thoroughly can we plan/design/roadmap, and how far?
2. How well can squads consume and implement the designs/plans/roadmap we
   update now?
3. What external procedural guidance sharpens automating planning, design,
   scheduling, dispatch, and prompt construction?
4. How do "senses" feed the planner direct feedback on squad performance,
   experience, and produced work — and how to design now so that's
   reachable later (benchmark + optimization + config hot-swap)?

---

## 1. How far can we roadmap, and how thoroughly?

### The planning horizon is bounded by *substrate maturity*, not ambition

The roadmap already spans M0–M9 plus M3 (The Network). The research wave
extended it forward (autonomy-strategy §7) into a phased arc:
C6 planner → guardrails (Wave B) → security baseline (Wave C) →
benchmark/cost circuit (Waves D/E) → MCP/A2A interop (F) → networked fleet (G).

The honest rule for "how far": **plan one milestone deep in detail, and
two-plus milestones out in sketch.** We should not write granular
implementation tasks for the fleet (M3/G) today — its design must wait for
A–C to be real, because it's gated on them. What we *can* do now:

- **Detail wave**: C6 (planner) — done, as the build plan.
- **Sketch waves**: B (guardrails), C (security baseline), D/E (benchmark +
  cheap-inference), F (MCP/A2A), G (fleet). Each has a design-doc anchor
  (autonomy-strategy §7 or the relevant design doc); none has a build plan yet.
- **Long-horizon framing only**: consulting workforce, fleet cost ledger,
  federated episodic memory. These get a paragraph, not a spec, until the
  gated waves land.

This keeps the loop's own planning from drowning in unconsumable detail — the
same discipline we applied to C6's scope.

### Thoroughness bar per item

Every roadmap item we actively work should reach the "zero-further-interview"
standard (the design docs' stated bar): explicit dependency edges, acceptance
criteria, and a verification command. Items beyond the detail wave only need
enough shape to be scannable as planner input (milestone, status, blocked,
target wave). This is what makes the roadmap a *consumable* artifact rather
than a prose document.

---

## 2. How well can squads consume the designs/plans/roadmap?

### Consumption is already designed, and now partly implemented

The consumption path is the bean/dispatch pipeline (squad-startup-automation
§4–§7): each role reads `dispatch.md`, harvests beans from its inbox, digests
them (acts), and husks results (journals/commits). The prompt matrix
(`generate-prompt`, skeleton→bones→flesh, W5) turns the *structured fields* of
a task — not free-form prose — into each role's first prompt. That is
precisely the MetaGPT lesson: squads consume *schema'd artifacts*, and the
next agent's prompt is built from them.

So the roadmap → squad path is already sound in design and partly in code.
The gaps that remain are:

| Consumption gap | What closes it | Where |
|---|---|---|
| Roadmap is markdown prose/tables, not a machine schema | C6's roadmap parser (Wave 0) emits structured gaps | C6 plan W0 |
| Task beans carry free-form task strings | C6 emits v3 records with `:type/:assigned-role/:verification/:depends-on` | C6 plan W1.3 |
| Prompt construction is per-role static-ish | W5 prompt matrix already exists (`generate-prompt`) | hngh-up/prompt-matrix |
| No objective completion gate | v3 `:verification` command + verifier-only transitions | C6 plan W1–W2 |
| No feedback from prior work into the planner | C8/C9 benchmark dataset → confidence (future) | squad-autonomy §10–11, §3 here |

**Capacity verdict**: squads can already consume a well-formed task and
produce verifiable work. The bind is upstream — making the roadmap machine-
readable and the emitted tasks well-formed — which is exactly C6's job. So
the order is right: build the consumer's input (C6) before the consumer
scales.

### Consumption contract (what a squad needs to implement well)

From the research + existing design, a squad implements reliably when each
dispatched unit carries:
1. **A scoped objective** (milestone + wave + one reviewable artifact).
2. **Explicit dependency edges** (so it doesn't rediscover inputs).
3. **A runnable verification** (`:command`, all-green = regression + repro).
4. **A bounded budget** (per-task step/token caps, per-cycle budget).
5. **A reflection hook** (what failed/why/what next — the husk).
This is what C6 emits per task; it's also what makes a squad's output
consumable by the *next* planner cycle (dedup, confidence, hot-swap).

---

## 3. External procedural guidance (survey-grounded)

### Agents as scaffold + model; self-improvement as a scaffold-update operator

The strongest external anchor is the self-improvement survey (arxiv
2607.13104): model a modern agent as **θ (foundation model) + Σ (operational
scaffold: prompts, memory, tools, control logic)**. Self-improvement is a
self-induced update operator that commits updates to θ or Σ. Two pathways:

- **Foundation-model improvement** (update θ): training/fine-tuning — expensive,
  not our daily path.
- **Scaffolding improvement** (update Σ): the cheap, high-leverage path —
  update **prompts**, **memory**, **tools**, or full configuration. This is
  where Hngh's planner should live.

### Prompt-refinement ladder (the "senses → planner feedback" spine)

The survey orders scaffold optimization by signal structure, from most
heuristic to most automated:

| Level | Signal | Example (survey) | Hngh hook |
|---|---|---|---|
| 1. Scalar-feedback optimization | a score | argmax over prompt candidates | C8/C9 benchmark yields scalar per (strategy, tier, task-tag) |
| 2. Qualitative-feedback refinement | critique text | Reflexion verbal introspection; MAPS rule induction; Chain-of-Hindsight | squad husk reflections ("what failed / why") fed back |
| 3. Population-based evolution | set of candidates | evolutionary prompt optimizers | vary one prompt dimension across squads, keep the winner |
| 4. Textual-gradient optimization | derived instruction | refined system prompt from failure cases | documented learning → prompt-matrix skeleton update |

**The practical takeaway**: Hngh's planner should consume *both* scalar scores
(C8/C9) and qualitative critiques (husk retrospectives), and treat the prompt
matrix + model-pareto as the search space for levels 3–4. That is the full
feedback arc the user describes — and it all funnels into C6's `confidence`
weighting and the recommended-strategy selection.

### Procedural dispatch / scheduling guidance

- **Orchestrator owns the loop, not the agents** — sequencing, stall detection
  (progress, not liveness), and termination are harness responsibilities
  (LangGraph caps, Magentic-One ledger, AutoGPT pathology). Already in C6 W2.
- **Prioritization heuristics** — priority × confidence × cost, recomputed each
  cycle so a low-item can jump the line when context changes (matches the
  local-model queue's living-backlog rule in startup-automation).
- **Long-running-task hygiene** — durable state, skip-if-running, exponential
  backoff on retries, and a coordinator that distributes to specialists of
  different durations. C6's per-task caps + backlog rescan encode this.
- **Filesystem as the orchestrator** (community consensus): "for a single-user
  system, the filesystem is the orchestration layer" — Hngh's git-backed
  dispatch tree is already the right choice; don't replace it with a heavier
  framework.

### Prompt construction (procedural + model-assisted)

Already designed: `generate-prompt` (skeleton→bones→flesh) builds each role's
prompt procedurally (who/what/where/when/why/how from structured fields), with
a cheap-model "flesh" pass only when budget allows, skipped when local-model
assigned. The addition from the survey: make the *skeleton itself* a hot-swap
candidate (level 2–3 refinement on the skeleton dimensions) rather than a
fixed template. C6's decomposition should call `generate-prompt` for the
dispatch, and C8/C9 should treat prompt dimensions as measurable knobs.

---

## 4. Senses → planner direct feedback (design the hook now, implement later)

### The requirement

The planner needs direct feedback on: **squad performance** (did it complete,
how fast, at what cost, did verification pass), **experience** (what the
husks recorded), and **the work they produce** (verification results,
artifacts). This is exactly the C8/C9 "squads testing squads" dataset plus the
husk retrospectives.

### Design the reference now

C6's build plan should carry (and this doc records) a *design hook* — a named,
shaped, but not-yet-implemented interface the planner will subscribe to:

```
planner-feedback-source
  scalar       ← benchmark dataset (C8/C9): {strategy, task-tag, model-tier,
                 completion, cost, quality} per squad run
  qualitative  ← husk retrospectives: {what failed, why, what next}
  experiential ← avatar :experience counters (metabolism §4) + verification
                 history per role; also fed by the social-senses thought-trace
                 layer (`docs/design/social-senses.md` §4) — a cheap
                 "what this agent was likely doing" signal for intent/state
planner-consumer
  confidence ← f(scalar, qualitative)   # feeds C6 weighting
  strategy   ← argmax over scalar per task-tag (recommended squad strategy)
  hot-swap   ← propose Σ update (prompt skeleton, model-tier, squad layout)
                 when a better configuration beats the incumbent on scalar
```

**Deliberately deferred**: the hot-swap *executor* (actually applying a new
squad config mid-flight) is NOT in C6 v1. It's a later wave (gated on C8/C9
producing trusted scalars and the security baseline/guardrails being in, so a
"better config" cannot be a jailbreak). But the *interface* — a typed
`planner-feedback-source` the planner reads — is designed now so C8/C9 and
the senses layer can be implemented against it without redesigning C6.

### Config hot-swap strategies (senses fully implemented)

Later, when senses (metabolism §3) and benchmarks are real:
- **Prompt hot-swap**: swap a role's skeleton for the highest-scoring variant
  on that task-tag (level 2–3 refinement), with a shadow/rollback.
- **Model-tier hot-swap**: promote a cheaper model to a role when its
  cost-per-successful-task beats the incumbent (model-pareto continual
  refinement).
- **Squad-layout hot-swap**: change member roles/strategy per task-tag when
  the benchmark shows a layout wins.
- **Experience-aware autonomy**: roles with high verified experience get less
  PM oversight (metabolism §4) — planner uses `:experience` + verification
  history to lower its review burden safely.
All of these are *planner-consumer* operations over the `planner-feedback-
source`; none are built in C6 v1, but the input contract is fixed now.

### Why fixed now prevents rework

If C6 v1 hard-codes `confidence = 0.5` (the placeholder), the weighting
function must still *read* from a feedback-source module, not inline a
constant. That keeps the C8/C9 wire-in to "implement the source," not "rip
out the planner." This is the same ports-and-adapters discipline the repo
already follows.

---

## 5. Consolidated decisions for the planner

| # | Decision | Value |
|---|---|---|
| P1 | Plasma of the loop | procedural scan/weight/schedule; LLM only for decomposition |
| P2 | Feedback contract | `planner-feedback-source` (scalar + qualitative + experiential) designed now, consumed by `confidence`/`strategy`/`hot-swap` later |
| P3 | Confidence placeholder | read from module; default 0.5 until C8/C9 fill it |
| P4 | Task granularity | one reviewable artifact per task; fan-out capped (4–220× token study) |
| P5 | Cost safety | per-cycle budget + per-task caps in code, never prompts; fail closed |
| P6 | Self-gated | C6 queues tasks; core-file self-modification waits for guardrails + security |
| P7 | Consumption contract | every emitted task: scope + deps + runnable verification + budget + reflection hook |
| P8 | Hot-swap | designed (interface), not built; gated on C8/C9 + security/guardrails |
| P9 | Guard-rail loop | every dispatched task runs a multi-pass dev→review→verify loop with bounded retries + procedural evidence-check; never self-review alone (live-orchestration L2) |
| P10 | Observation surface | planner activity + squad state legible via mission-control observe + TUI peep depth, so humans can verify underway (live-orchestration L1) |
| P11 | Priority steering | situations scored (impact×urgency×spread) and emitted as `/steer`/opencode-correct by priority, not by human alertness (live-orchestration L3) |
| P12 | Continual param optimization | shadow-then-promote optimizer over per-role temperature/token/logit params, driven by C8/C9 outcomes (live-orchestration L5) |

`live-orchestration.md` carries the full L1–L5 detail; P9–P12 record how it
threads into the planner loop's decisions. P8 and P12 share the same gating:
both wait on C8/C9 data + guardrails being real.

---

## 6. Open questions

- Exact shape of the decomposition prompt (resolve in C6 W1 against the W5
  prompt matrix).
- Whether `confidence` should start at 0.5 or a cheap heuristic (documented,
  revisit at C8/C9).
- Hot-swap rollout safety: shadow-then-promote per task-tag vs per-role —
  defer to the C8/C9 era, but design the input so either is possible.
- Fleet cost-ledger and federated episodic memory remain M3-era open items.

---

## Attribution

Orchestrator analysis grounded in the implemented codebase + the
self-improvement survey (arxiv 2607.13104) and prior research reports.
deepseek-v4-flash-0731 via openrouter (Hermes TUI).
