# Design Seed — Encoded Filename Metadata for Agent Direction

**Status**: Idea capture — NOT a build spec. Seed for later evaluation.
**Date**: 2026-08-08
**Owner**: user brief (riff) + Hngh self-development.
**Intent**: record the idea faithfully so it can be rationally evaluated later,
not lost in conversation.

> Purpose of this file: hold the idea, sketch the shape, note open questions,
> and leave a review gate. It is deliberately NOT a wave-ordered build plan.
> The discipline (per user): research + scaffold requirements from available
> documentation first, avoid forced experimentation, find pieces that suit
> each other, and only fold this in where it genuinely serves Hngh.

---

## The idea

Certain files that agents read regularly could be named with a **standardized,
decodable filename format** encoding metadata that helps agents (and their
orchestrators) understand:

- **who / what** the file is intended for (role, agent, model tier),
- **which project / scope** it belongs to,
- **which lines / characters / sections** should be read by which kinds of
  agents (a "read gate" or per-agent reading hint),
- semantic tags that direct or instruct agents with encoded meaning.

The hypothesis: filename-embedded metadata (a structured, machine-readable
convention layered onto an otherwise human-readable name) could let Hngh and
its squad agents route, scope, and read files more cheaply and correctly —
without opening every file to discover its intent.

Notably: Hngh already runs on a **git-versioned, file-tree state** with
**beans** as the squad "nutrient/instruction" medium and a **dispatch tree**
of in/out/task files. An encoded filename convention could complement the
beans setup (a naming-side signal that pairs with the bean payloads), rather
than replace it.

## Shape (rough sketch — not a schema)

A plausible but UNCONFIRMED shape (to be researched before adopted):

```
<target>.<project>.<read-hint>.<tag>.<ext>
```

- `<target>` — intended consumer (e.g. `pm`, `designer`, `coder`, `all`,
  `worker`, a specific model tier).
- `<project>` — project/scope id.
- `<read-hint>` — a bounded hint about which content an agent should read
  (e.g. `head=40`, `sec=2-4`, `all`); meant to cut token cost by scoping reads.
- `<tag>` — semantic keyword(s).

All examples here are illustrative, not decisions.

## Where it might fit Hngh (to evaluate)

- Filenames are already the "comm-line" in the dispatch tree; a decode step
  could be a small procedural function, no LLM in the hot path.
- Could pair with **beans** — filename as a transport/vessel hint, bean
  payload as the actual instruction.
- Could feed the **planner / situation-scoring** systems: a file whose name
  says "read by pm, head=40" gives a cheap, deterministic read/scope decision.
- Potential tie to **social-senses / thought-trace**: the encoded name is a
  handled, legible signal.

## Why it may matter (the seed's value)

Rigorous, procedural evaluation/categorization/scoring of *files and their
consumers* is a recurring need across Hngh's self-optimization and iterative
self-development. Seeds planted now (a naming convention + a decode primitive)
can blossom as Hngh's later work formalizes read-scoping, per-agent context,
and cost control. A convention is cheap to adopt early and hard to retrofit
late (rename costs), so it's worth a real evaluation even if the payoff is
ahead.

## Open questions (do NOT resolve here — resolve during a proper evaluation)

1. Is there prior art / an existing convention (e.g. some agent ecosystems
   already encode role/scopes into filenames or content headers)? Research
   first.
2. Stability vs. churn: renames are a real cost on a git-versioned tree.
   Would the encoding live in the filename, a sidecar, or the file's own
   header (e.g. a first-line directive)?
3. Decode primitive: a tiny CL parser (mirrors `situation-detectors` style —
   procedural, deterministic, fail-closed, no model). Misfit names → treated
   as plain filenames, never guessed.
4. Does read-scoping ("these lines for X") actually save tokens end-to-end,
   or does it add orchestration overhead? Measure before committing.
5. Interaction with existing beans/dispatch-tree naming; avoid a second,
   competing vocabulary.

## Review gate

Revisit for a proper evaluation when:
- a clear, motivated use case exists inside hngh (routing/scope/cost) that
  reads file metadata autonomously, AND
- we can research prior art + prototype a decode primitive with fixture
  tests (procedural, no model) without forcing it into the current waves.

Not on any current build path. Registered in `docs/project/backlog.md` as an
open design question.

## Attribution

User idea (riff), recorded by deepseek-v4-flash-0731 via openrouter (Hermes
TUI) on 2026-08-08.
