# Model Registry — Pareto Frontier for Squad Assignment

**Status**: Draft v0.1 (2026-08-03)
**Author**: PM (z-ai/glm-5.2, Hermes harness)
**Purpose**: Cost-optimized model selection for squad roles. Models plotted on
intelligence (Y) vs cost (X). Pareto frontier = models where no other model is
both cheaper AND more capable. Selection ordered by frontier position, filtered
by quota and budget.

---

## 1. Model table (Aug 2026, openrouter + local)

| Model | Provider | Input $/M | Output $/M | Context | Capability | Quota | Local? |
|---|---|---|---|---|---|---|---|
| gemma-4-12b-it-qat | unsloth (local) | 0 | 0 | 200K | 6/10 | unlimited | yes |
| unsloth/Qwen-AgentWorld-35B-A3B-GGUF | unsloth (local) | 0 | 0 | 200K | 6.5/10 | unlimited | yes |
| unsloth/Ornith-1.0-35B-GGUF | unsloth (local) | 0 | 0 | 200K | 6/10 | unlimited | yes |
| unsloth/Ornith-1.0-9B-GGUF | unsloth (local) | 0 | 0 | 200K | 5.5/10 | unlimited | yes |
| deepseek-v4-flash | openrouter | 0.09 | 0.09 | 1M | 7/10 | paid | no |
| deepseek-v4-flash-0731 | openrouter | 0.09* | 0.09* | 1M | 7.5/10 | paid | no |
| gpt-5.6-luna | openai | 0.10 | 0.10 | 1M | 7.5/10 | paid | no |
| mimo-v2.5 | openrouter | 0.14 | 0.14 | 1M | 6.5/10 | paid | no |
| gemini-3.5-flash-lite | gemini | 0.30 | 0.30 | 1M | 6.5/10 | free tier | no |
| kimi-k2.6 | kimi-coding | 0.60 | 0.60 | 262K | 8/10 | paid | no |
| deepseek-v4-pro | openrouter | 0.435 | 0.435 | 1M | 8/10 | paid | no |
| mimo-v2.5-pro | openrouter | 0.435 | 0.435 | 1M | 7.5/10 | xiaomi free quota | no |
| glm-5.2 | openrouter | 0.40 | 0.40 | 1M | 8.5/10 | paid | no |
| gemini-3.6-flash | openrouter | 1.50 | 1.50 | 1M | 8/10 | paid | no |
| kimi-k3 | kimi-coding | 3.00 | 3.00 | 1M | 9/10 | paid (K3 reserved) | no |
| nvidia/nemotron-3-ultra-550b-a55b:free | openrouter | 0 | 0 | 1M | 7.5/10 | 1000/day free | no |
| nvidia/nemotron-3-super-120b-a12b:free | openrouter | 0 | 0 | 262K | 7/10 | 1000/day free | no |
| google/gemma-4-31b-it:free | openrouter | 0 | 0 | 262K | 7/10 | 1000/day free | no |
| google/gemma-4-26b-a4b-it:free | openrouter | 0 | 0 | 262K | 6.5/10 | 1000/day free | no |
| openai/gpt-oss-20b:free | openrouter | 0 | 0 | 131K | 6.5/10 | 1000/day free | no |
| poolside/laguna-s-2.1:free | openrouter | 0 | 0 | 262K | 6.5/10 | 1000/day free | no |
| poolside/laguna-xs-2.1:free | openrouter | 0 | 0 | 262K | 6/10 | 1000/day free | no |
| cohere/north-mini-code:free | openrouter | 0 | 0 | 256K | 6/10 | 1000/day free | no |
| inclusionai/ling-3.0-tiny:free | openrouter | 0 | 0 | 262K | 5.5/10 | 1000/day free | no |
| nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free | openrouter | 0 | 0 | 256K | 6/10 | 1000/day free | no |
| nvidia/nemotron-nano-12b-v2-vl:free | openrouter | 0 | 0 | 128K | 5.5/10 | 1000/day free | no |

Capability scores are sourced from available benchmarks where possible (e.g.
LMSYS Chatbot Arena, HumanEval, MMLU). Where no benchmark exists for a model,
scores are conservative estimates. Refine continually with real benchmark
data from Wave 8 (benchmark squad) and external sources (LMSYS, Artificial
Analysis, HuggingFace leaderboards). The scores are intentionally conservative —
better to underestimate and be surprised than overestimate and be disappointed.

\* flash-family price tier — verify on OpenRouter catalog. `deepseek-v4-flash-0731`
is the flagship flash variant; primary for most roles per the 2026-08-05 model
mandate (docs/project/decisions.md, journal/20260805-model-mandate.md).

**External benchmark sources** (check periodically, not per-dispatch):
- OpenRouter catalog (https://openrouter.ai/api/v1/models) — authoritative for what exists: id, pricing, context, modality
- LM Arena PPE datasets (https://huggingface.co/datasets-server) — per-model mean scores: MBPP-Plus, GPQA, IFEval, MMLU-Pro, MATH
- Aider Polyglot leaderboard (https://aider.chat/docs/leaderboards/) — coding capability
- LMSYS Chatbot Arena (https://lmarena.ai) — head-to-head ELO ratings
- Artificial Analysis (https://artificialanalysis.ai) — cost/performance scatter
- HuggingFace Open LLM Leaderboard — for local models

**Automated sourcing**: `scripts/fetch-model-benchmarks.sh` pulls the OpenRouter
catalog + LM Arena PPE + Aider leaderboard into a dated snapshot
(`data/model-benchmarks-<YYYYMMDD>.json`). Run it before refreshing the
tables above; capability scores are estimates where no benchmark covers the
model. Free-tier IDs were refreshed against the live catalog 2026-08-06 —
the old short IDs (nemotron-ultra:free etc.) 404 on OpenRouter.

---

## 2. Pareto frontier

A model is on the Pareto frontier if no other model is both cheaper AND more
capable. The frontier is the set of models that dominate everything below
their price point.

```
Capability (Y, 1-10)
 10 |
  9 |                                    * kimi-k3 ($3.00)
  8 |          * glm-5.2 ($0.40) ------
  8 |     * kimi-k2.6 ($0.60)        * deepseek-v4-pro ($0.435)
  7.5| * gpt-5.6-luna ($0.10) -- * mimo-v2.5-pro ($0.435)
  7 | * deepseek-v4-flash ($0.09) --
  6.5|    * gemini-3.5-flash-lite ($0.30)  * nemotron-ultra:free ($0)
  6 | * gemma-4-12b ($0, local) --  * nemotron-super:free ($0)
  5.5|          * north-mini-code:free ($0)
  5 |                    * nemotron-nano:free ($0)
    +---------------------------------------------------> Cost ($/M, X)
     0    0.09  0.10  0.14  0.30  0.40  0.435  0.60  1.50  3.00
```

### Frontier models (dominated by nothing cheaper AND better)

| Rank | Model | Cost $/M | Capability | Role fit |
|---|---|---|---|---|
| 1 | gemma-4-12b (local) | 0 | 6/10 | procedural, creative riff, queued background |
| 2 | deepseek-v4-flash | 0.09 | 7/10 | coder, worker (cheapest capable) |
| 2a | deepseek-v4-flash-0731 | 0.09 | 7.5/10 | primary for most roles (2026-08-05 mandate) |
| 3 | gpt-5.6-luna | 0.10 | 7.5/10 | coder, worker (cheap, high speed) |
| 4 | glm-5.2 | 0.40 | 8.5/10 | PM, designer (best intelligence/cost ratio) |
| 5 | kimi-k3 | 3.00 | 9/10 | novel design forks, critical reviews only (K3 reserved) |

### Off-frontier (dominated by a cheaper-and-better-or-equal option)

| Model | Dominated by | Reason |
|---|---|---|
| mimo-v2.5 ($0.14) | deepseek-v4-flash ($0.09, 7/10) | cheaper and more capable |
| deepseek-v4-pro ($0.435) | glm-5.2 ($0.40, 8.5/10) | cheaper and more capable |
| mimo-v2.5-pro ($0.435) | glm-5.2 ($0.40, 8.5/10) | cheaper and more capable |
| gemini-3.6-flash ($1.50) | glm-5.2 ($0.40, 8.5/10) | much cheaper, equal or better |
| nemotron-ultra:free | gemma-4-12b ($0, 6/10) | local is equal capability, no quota limit |

Off-frontier models are still useful as fallbacks when frontier models hit
quota limits. The free-tier models (nemotron, north-mini) serve as
zero-cost fallbacks when budget is exhausted.

---

## 3. Per-role selection from the frontier

| Role | Primary (frontier) | Fallback 1 | Fallback 2 | Free tier (best, distributed) | Local fallback |
|---|---|---|---|---|---|
| PM | glm-5.2 ($0.40, 8.5) | deepseek-v4-flash-0731 ($0.09*, 7.5) | gpt-5.6-luna ($0.10, 7.5) | nemotron-3-ultra-550b-a55b:free (7.5) → gemma-4-31b-it:free (7.0) | never |
| Designer | glm-5.2 ($0.40, 8.5) | deepseek-v4-flash-0731 ($0.09*, 7.5) | gpt-5.6-luna ($0.10, 7.5) | gemma-4-31b-it:free (7.0) → nemotron-3-super-120b-a12b:free (7.0) | Qwen-AgentWorld-35B (6.5) → gemma-4-12b (6.0) |
| Coder | deepseek-v4-flash-0731 ($0.09*, 7.5) | deepseek-v4-flash ($0.09, 7) | gpt-5.6-luna ($0.10, 7.5) | gpt-oss-20b:free (6.5) → laguna-s-2.1:free (6.5) → north-mini-code:free (6.0) | Qwen-AgentWorld-35B (6.5) → gemma-4-12b (6.0) |
| Artist | deepseek-v4-flash-0731 ($0.09*, 7.5, visual-eng) | qwen3.7-flash (7.0, vision) | gpt-5.6-luna ($0.10, 7.5) | gemma-4-31b-it:free (7.0, multimodal) → nemotron-3-nano-omni-30b-a3b-reasoning:free (6.0) → nemotron-nano-12b-v2-vl:free (5.5, vision) | never local |
| Accountant | deepseek-v4-flash-0731 ($0.09*, 7.5) | deepseek-v4-flash ($0.09, 7) | gpt-5.6-luna ($0.10, 7.5) | gpt-oss-20b:free (6.5) → gemma-4-26b-a4b-it:free (6.5) | Qwen-AgentWorld-35B (6.5) → gemma-4-12b (6.0) |
| Worker | deepseek-v4-flash-0731 ($0.09*, 7.5) | deepseek-v4-flash ($0.09, 7) | gpt-5.6-luna ($0.10, 7.5) | gemma-4-26b-a4b-it:free (6.5) → north-mini-code:free (6.0) → ling-3.0-tiny:free (5.5) | Qwen-AgentWorld-35B (6.5) → gemma-4-12b (6.0) |

Note: Artist primary moved from glm-5.2 to deepseek-v4-flash-0731 (visual-
engineering tier) per the 2026-08-05 mandate; glm-5.2 stays in the Artist
vision fallback chain. Qwen 3.7 flash (`openrouter/qwen/qwen3.7-flash`) is the
vision looker for image recognition/review, with fallbacks mimo-v2.5 ->
minimax-m3 -> gpt-5.6-luna -> gemini-3.5-flash-lite -> local gemma.

---

## 4. Quota and budget gates

### Quota tracking

| Constraint | Mechanism |
|---|---|
| K3 reserved | Only for novel design forks and critical reviews. PM must explicitly authorize. |
| Copilot quota | gpt-5.6-luna uses GitHub Copilot. Track via copilot API usage. |
| Free tier 1000/day | OpenRouter :free models. Shared across all roles using free models. |
| Daily budget | `$1/day` remote API spend. Check via `llm-budget` before dispatch. |
| VRAM | Local model blocks on unsloth availability. Check resource-manager. |

### Selection algorithm

```
select-role-model(role, scenario, budget-remaining, vram-available):
  1. Get role's fallback chain from the per-role table
  2. For each model in chain (primary -> fallback -> ... -> local):
     a. If model is local: check VRAM available (resource gate)
     b. If model is remote: check budget remaining >= estimated cost
     c. If model is K3: check PM authorization
     d. If model is :free: check daily free-tier count
     e. If all gates pass: return model
  3. If nothing passes: return nil (role cannot be dispatched)
```

### Budget estimation per dispatch

```
estimated-cost = model-input-rate * estimated-input-tokens
               + model-output-rate * estimated-output-tokens

estimated-input-tokens = context-size (AGENTS.md + plans + system + OptMem)
estimated-output-tokens = task-complexity-factor * 2000
```

The estimation is rough. Track actual costs against estimates over time
(Accountant's job) and adjust the complexity factor per scenario.

---

## 5. Embedding model recommendations in design sessions

Each projected design session (D2-D9) includes a model recommendation block:

```markdown
## Model recommendations

| Role | Model | $/M | Est. tokens | Est. cost |
|---|---|---|---|---|
| Designer | glm-5.2 | 0.40 | 50K | $0.02 |
| Coder | deepseek-v4-flash-0731 | 0.09 | 100K | $0.009 |
| Accountant | deepseek-v4-flash-0731 | 0.09 | 10K | $0.0009 |
| Artist | deepseek-v4-flash-0731 | 0.09 | 20K | $0.0018 |

Total estimated cost: $0.03
Budget gate: passes ($1/day, $0.04 < remaining)
```

The PM's generate-pm-prompt includes this block so the PM knows what models
the squad will use before dispatching. If the budget gate fails, the PM
downgrades models along the fallback chain until it passes.

---

## 6. Pushing the pattern into automation

The projected design session pattern (D2-D9) can itself be automated. The
planner (Wave 7, C6) generates design session specs the same way it generates
task specs:

1. Scan roadmap for next unstarted wave
2. Read the wave's design doc section
3. Determine which roles are needed (from the design doc)
4. Generate a projected design session spec (loose structure, like D2-D9)
5. Assign models from the Pareto frontier table
6. Check preconditions and budget gates
7. Plant the session spec as a task bean in the Designer's inbox
8. The Designer digests it, produces the detailed spec, plants implementation
   beans in the Coder's inbox

This makes the session projection pattern recursive — the planner generates
design sessions, which produce implementation specs, which produce code. Each
level is a bean being planted, digested, and husked. The git-backed state
captures every level for rollback and benchmarking.

### How far can we push it?

As far as the precondition gates allow. The planner can project sessions
arbitrarily deep into the future — D10, D11, D20 — as long as each session's
preconditions are declared and checked at dispatch time. Sessions whose
preconditions aren't met stay staged (planted but not growing). When prior
waves complete, preconditions re-evaluate and staged sessions become ripe.

The limit is not depth — it's staleness. A session projected 10 waves ahead
will likely need revision before its preconditions are met. But that's fine:
the precondition gate catches it, the PM re-projects, and the git history
preserves the original for comparison.

---

## 7. Kick-start readiness assessment

### What we have now

| Capability | Status | What works |
|---|---|---|
| PM-first-prompt generation | done | generate-pm-prompt assembles full context |
| Model Pareto table | this doc | static table, procedural selection algorithm |
| Projected design sessions | done | D2-D9 loose structures with participants |
| Design docs | done | squad-startup-automation.md, beans-aesthetic.md |
| Plan | done | .hermes/plans/2026-08-03_squad-automation-bootstrapping.md |
| Test-count lint | done | make lint-counts |
| squad-up script | exists | static prompts, cascading Konsole, squad-seats.conf |
| OptMem | running | shared memory for inter-role comms |
| 1393/1393 tests green | verified | build clean |

### What's missing for full automated kick-start

| Gap | Blocks what | Workaround for manual kick-start |
|---|---|---|
| Per-role prompt generation | other roles get static prompts | PM writes per-role prompts manually, plants in OptMem |
| Dispatch tree | bean bus, git rollback | use OptMem + filesystem manually |
| File-change notification | role senses | roles poll OptMem and files manually |
| Model selection automation | per-role model assignment | use the Pareto table manually, edit squad-seats.conf |
| Bean lifecycle | structured comms | use OptMem notes as ad-hoc beans |

### What's missing for ralph-until-stopped

| Gap | Blocks what |
|---|---|
| Self-improvement planner (Wave 7) | autonomous wave-to-wave progression |
| squad-up integration (Wave 6) | launching roles with generated prompts |
| Dispatch tree (Wave 3) | structured squad state |

### Minimal path to kick-start (today, manual)

1. PM gets generated first prompt (we have this)
2. PM reads design docs and projected sessions (files exist)
3. PM edits squad-seats.conf with Pareto-optimal models from this table
4. PM writes per-role prompts manually (using the prompt matrix skeleton structure from the design doc, filled by hand)
5. PM runs `squad-up` to launch roles with those prompts
6. Roles use OptMem for comms, poll files for changes
7. PM monitors via OptMem, reviews output, dispatches next session
8. Ralph: PM keeps dispatching D2, D3, D4... until stopped or blocked

This is manual but functional. The squad works on Waves 2-5 (building the
infrastructure) while using ad-hoc versions of it (OptMem as bean bus, manual
file checks as senses). As each wave lands, the manual processes get replaced
by automated ones. The squad eats its own dogfood.

### Minimal path to automated kick-start (after Wave 6)

1. `hngh up "implement wave 2: file-change notification" --auto` generates
   PM prompt, creates dispatch tree, assigns Pareto-optimal models, plants
   beans, launches roles
2. PM orients from generated prompt, reads projected session D2, dispatches
   Designer
3. Designer produces spec, plants implementation bean for Coder
4. Coder implements, tests green, husks
5. PM verifies, updates roadmap, dispatches D3
6. Ralph: repeat until all waves done or stopped

This requires Waves 2-6 to be built first. The squad builds its own
infrastructure, then uses it.

---

## 8. Attribution

PM — z-ai/glm-5.2 via openrouter, Hermes harness.
Model pricing — OpenRouter catalog, Aug 2026. Capability scores — rough
qualitative estimates, refine with benchmark data from Wave 8.
