# Cost tiering - local for mechanical, quota for intelligence, paid last

Status: DESIGN - operator directive 2026-09-10. Companions:
[rehearsal-and-self-order.md](rehearsal-and-self-order.md) (rehearsal
lane), [meta-patterns.md](meta-patterns.md) (pattern 11: bounded
evaluation), [../research/2026-09-10-quota-utilization.md](../research/2026-09-10-quota-utilization.md)
(the honest boundary), and the demotion machinery
(automation/lib/model-demote.sh, eb8c242).

> Spend belongs where the thinking is. Everything else is motion.

## What the machine actually pays for

Three spend channels today, each with its own ladder and its own
blindsight:

1. **Delegated sessions** (`automation/lib/launch-session.sh`):
   `omp -p --model $SESSION_MODEL` - the cost is whatever the omp
   model id resolves to. Selection: `select_model` in
   `automation/scripts/overnight-cycle.sh` (env > quota-row >
   local-bench > paid-fallback), demotion-aware per
   `automation/lib/model-demote.sh`.
2. **Bounded model calls** (`automation/lib/model.sh` `model_call`):
   the research beat, the review beat, the plan drafter - curl-based
   legs (unsloth -> ollama -> deck, with kimi/lobehub quota legs
   gated by `quota_pace_blocked` caps and `MODEL_PIN`).
3. **The operator session itself** (this conversation): the strong
   model, paid, and the only executor for T3 (below).

## The taxonomy

Evidence base: today's sessions ran a live split - the SimDesign
worker on glm-5.3-flash:high did design and diagnosis work (T2/T3
shapes), the QueueDeps worker on qwen-flash did mechanical
coordination cleanly (T1); both are the tiering proof the operator
asked for. The research beat's kimi calls (quota-utilization doc:
26 calls, 22% of cap, all synthesis-shaped) are T2 working as
intended.

| Tier | Work shapes (real lanes) | Cost-optimal executor |
|---|---|---|
| T1 mechanical | test runs, renames, log parsing, ledger appends, format fixes, data collection (the worker fan-out slots, evolve-ui batches, telemetry) | local unsloth always (`model_call` local chain; bench-scored) |
| T2 bounded intelligence | research synthesis (33-research-beat), reviews (04-review-prep, 00-dashboard-self-review), plan-step execution with clear specs (overnight sessions on accepted plans) | quota legs first (`kimi_chat`/`lobehub_chat` bounded calls, or omp-addressable quota models for sessions), local fallback |
| T3 deep intelligence | design, root-cause diagnosis, architecture, cross-system judgment (the operator session; ceremony verdicts stay deterministic) | best available: quota top, then paid cash - never local for the deciding step |

The honest observation from the 2026-09-09 spend: the cap counted a
T1-shaped session on a bad local model and a T2 session identically -
the taxonomy exists so the cap sees what it is actually buying.

## Decomposition rule

Plans are already the decomposition unit
(docs/project/plans/README.md); what is missing is the class tag. A
step may carry a `class=T1|T2|T3` marker in its text (checked by the
same conventions as the Verification line). The selector reads it:

- untagged defaults to T2 (today's default is the safe middle);
- T1 steps are eligible for local-model delegated sessions even when
  bench-trust is the only signal;
- T2 steps prefer the quota rung (the session-model-preference lane,
  health-gated per step 9);
- T3 steps are never machine-decomposed further - they route to the
  director/agent layer (operator session or a certified strong model)
  by staying in plans the selector cannot launch mechanically.

Decomposition quality is a plan-authoring concern: when a plan's step
can only be T3, the author either decomposes it into T1/T2 steps or
leaves it for the director. The overnight-cycle "Plan authoring"
prompt block gains one line: tag each step's class.

## The foresight loop (cost prevention)

Spend avoided is spend saved; three mechanisms already exist and one
is designed:

- **Rehearsal lane** ([rehearsal-and-self-order.md](rehearsal-and-self-order.md)):
  the certificate loop minus the mutating tail - catches a doomed
  candidate before its session burns.
- **Cyclic blocker recognition**: the plan-identity guard
  (accept-plans.py, e2b4701 lineage), the quota-leg health gate
  (step 9), and the gate-rerun capture (f1365aed) - each converts a
  repeated failure into filed evidence instead of repeated spend.
- **Pattern 11** ([meta-patterns.md](meta-patterns.md)): bounded
  evaluation; a dead-end identified in one probe costs a probe, not a
  night.

Together they are the "foresight" layer: simulation before mutation,
health before routing, identification before persistence.

## Honest constraints

- The operator session is the T3 gate. Kernel-boundary decisions, the
  certificate ceremony's operator-profile, and anything the strong
  model's judgment is paid for stay there. No quota leg "becomes" the
  director.
- omp sessions address omp-routable models only (the found boundary,
  quota-utilization doc): kimi_chat/lobehub_chat are curl helpers
  serving the bounded-call lane, not session launchers. The quota row
  for SESSIONS names omp-addressable quota models; kimi/lobehub serve
  the bounded-call lane directly.
- LobeHub's endpoint 404s since config (quota-utilization doc); the
  T2 quota tier is kimi-first until that is diagnosed.
- The env override (OVERNIGHT_MODEL) outranks everything by design:
  operator steering is not a cost decision, it is the operator.

## Per-lane ladder after this design

| Lane | Order |
|---|---|
| Overnight sessions | env > quota (health-gated, step 9) > local-bench > paid; class tags allow T1 steps to pin local |
| Research beats | model_call with MODEL_PIN=kimi/lobehub when quota live (the existing pin), local chain fallback |
| Review beats | same as research (T2); unparseable review = bad-execution signal into the demotion counter (step 10 of stall-recovery) |
| Worker fan-out | session-model-per-worker-class (the rung below) |
