# Live Orchestration — Active Monitoring, Steering, Observation, and Guard-rails

**Status**: Design capture (2026-08-07). Extends C6/squad work.
**Cross-links**: `mission-control.lisp` (hngh-mc, tmux panes), `dashboard-tui.lisp`
(levels), `social-senses.md` (thought-trace, signals), `quota-spreader.md`
(cost gate), `planner-design-roadmap.md` (feedback-source), `autonomy-strategy.md`
(procedural guard-rails).

---

## 0. The core shift: live, not after-the-fact

> We don't want Hngh keeping track of squads after-the-fact. We want Hngh
> actively monitoring, orchestrating, and learning as work is *underway* —
> tuning itself to emerging circumstances, before problems become history.

Today most feedback is post-hoc: husks, journals, benchmark datasets. This doc
captures the **live layer**: Hngh watches squad work in motion, applies
procedural guard-rails continuously (multiple dev+review passes), surfaces
human-observable activity, and issues steering corrections mid-turn — scoring
and rank-ordering situations so steering happens at the right priority, not by
human alertness.

---

## 1. Procedural guard-rails (continuous, multi-pass)

Automatic work must be hard-gated by **procedural review at every step**, not
post-hoc. Design pattern (from autonomy-strategy §1, now made explicit):

- **Guard-loop inside dev**: for each squad work pass, run
  `test → review-artifact → regenerate-on-failure → verify`, bounded retries,
  then escalate. The guard-loop is procedural (deterministic tests + structural
  checks), never "the model reviews itself."
- **Multiple passes are the default**: development pass + review pass are
  separate squad roles/stages, not one merged step (MetaGPT SOP waterfall
  already referenced). A pass that fails its gate goes back, never forward.
- **Claim cross-checking (procedural)**: when a worker claims something is
  "impossible" or a coder asserts a functional requirement can't be met,
  Hngh runs an **evidence check** — does the trace/tests/system state support
  or refute the claim? Claims without supporting evidence are routed back for
  substantiation, not taken at face value. Every such claim-and-verdict is
  logged for the case base (this is the "impossible-but-actually-possible"
  pattern working for us, not against us).
- **Cost+resource guard**: quota-spreader + resource-gate consulted *during*
  the loop, not at launch (fail closed mid-run if a route is over.

### Guard-rail primitives (to build)
| Primitive | What it does | Building block |
|---|---|---|
| `evidence-check (claim context)` | does state support/refute the claim? | thought-trace + filesystem (social-senses §4) |
| `guard-loop-pass (work)` | one dev→review→verify pass, bounded | task-driver verification |
| `escalate (work reason)` | hand to human/senior when gates keep failing | signals :block + mission-control |

---

## 2. Observation surfaces: human-facing, easy access

> Testing for squads should involve easy-access, human-facing surfaces. Update
> hngh-mc to observe squads, and TUI to peep at their activity at varying depth.

Existing substrate: `mission-control` (hngh-mc) manages tmux panes; the TUI has
`*level-map*` (B1-overview / B3-events / B2-scheduler). Extend both:

### hngh-mc observes squads
- `hngh-mc observe <squad>` → open a pane/window that shows that squad's live
  activity: its dispatch tree, active beans, signals, recent thought-trace
  intent, ledger tail. Follow it (auto-scroll) or freeze.
- `hngh-mc observe --all` → a "squad wall": one pane per running squad, tiled.
- Deep-linking: click/collapse into a single member's stream (coder/worker/PM).
- `hngh-mc pause <squad>` / `steer` → human steering from the same surface
  (see §3).

### TUI peep at varying depth
- Extend `*level-map*` with squad views: `:squad-overview`, `:squad-members`,
  `:squad-thought-trace`, `:squad-signals`, `:squad-ledger`.
- **Depth/detail levels** per peep — overview (who/what/last-signal) to
  fine-grained (individual member's recent intent + the work artifact it's
  touching). Keyboard-driven depth toggle, no config file needed to look deeper.

### Why human senses aren't enough (the brief)
The PM's mental model of project state, a coder's reaction to functional
requirements, a worker's "impossible" claim — these are the signals a human
might miss and Hngh shouldn't. The observation layer makes the *underway*
state legible so a human can verify Hngh's judgment, without having to parse
every raw line. Hngh does the watching; the human does the "is this right"
check at whatever depth they want.

---

## 3. Steering: multi-session / mid-turn correction

> Orchestrate "/steer" for multiple sessions of Hermes; pause and correct
> Opencode. Both matter when a situation arises (e.g. one agent learns
> something the whole squad needs immediately). Score + rank situations to
> permit routine "/steer".

Existing: nothing wires cross-session steering yet (no plugin). This is the
highest-value new integration.

### Steering primitives
| Surface | Mechanism | Status |
|---|---|---|
| **Hermes `/steer`** | inject guidance into a running Hermes session mid-turn (Hermes supports in-turn steering) | build plugin |
| **opencode mid-turn** | opencode can be paused and fed corrective guidance between turns (verify exact mechanism; steer if possible, else pause→resume with note) | build plugin, verify |
| **Score + rank situations** | event → score → queue; periodic/routine steering by priority, not alertness | build priority router |

### Priority-scored steering
- Each situation (a new squad-wide fact, a gate failure, a claim dispute) gets a
  **priority score** from a small procedural rubric: impact × urgency × spread
  (how many members/sessions it affects). High-score → steer now; medium →
  batch into the next routine steering tick; low → log only.
- Example: **one agent learns something the whole squad needs** → high
  *spread* → immediate `/steer` to all squad members with the fact, before
  anyone else proceeds on stale assumptions.
- **No "/steer" prompt needed from the human** — that's the point: Hngh
  orchestrates the steer itself, by priority, and the human sees it happening
  on the observation wall. Human-gate stays available for the truly
  high-impact/irreversible cases.

### Steering is a first-class plugin
`hngh-steer` (new plugin): a priority router over signals/events that emits
`/steer`-shaped guidance to Hermes sessions and opencode correction inputs.
Same shape as signal :ask/:block escalation, but outward to the running
sessions rather than inward.

---

## 4. Continual parameter optimization

> Fine-tune temperature, token limits, logit-bias etc. — automate continual
> optimization of any parameter we can, for Hermes and Opencode both.

- **Config surface**: a per-role/per-model parameter table (temperature, max
  tokens in/out, stop sequences, and any logit-bias knobs the backend exposes).
  Config-first like quota-spreader: code defaults, overridable.
- **Optimization loop**: plug into C8/C9 benchmark — each (strategy, tier,
  task-tag) run records its parameter set + outcome. The optimizer proposes
  parameter deltas (temperature up/down, tighter token cap) on a schedule,
  shadows them against the incumbent, promotes a winner only when it beats on
  cost-adjusted success. This extends model-pareto's "continual refinement"
  from *model choice* to *parameter choice*.
- **Guard**: parameter changes are shadow-then-promote, rolled back on
  regression, and never exceed a bounded range. Same discipline as the
  hot-swap strategy (planner-design-roadmap §4) — designed but gated on
  C8/C9 datasets being real.

---

## 5. Full Hermes + Opencode integration plugins

The brief: build plugins to fully integrate Hngh into both Hermes and opencode,
like the rest (designed, planned, roadmapped).

- **Hermes plugin** (`hngh--hermes`): surface squad activity + steering through
  Hermes' own extension points; let Hngh read/write session state, observe and
  steer. Reuses hermes-agent + the CLI capabilities.
- **opencode plugin**: `hngh--opencode` — observe/steer opencode runs, feed the
  parameter table, route mid-run corrections. Verify opencode's steering
  surface (pause/insert-between-turns) before specifying exactness.
- Both are **M9+ waves** after the steering primitive (§3) exists, since the
  plugins are the end-points that the steer/orchestrate/observe layer
  drives.

---

## 6. Human-gate on dispatch (startable, not required)

> We want to be able to start a dispatch, and not be required to. Hngh may
> have better interfaces later; for now agents like this one configure and
> launch squads.

- Dispatch launches are **human-startable but not human-required**: the
  planner can start work, and the human can start it too, but neither is
  mandatory. The quota gate + dispatch-paused-p already provide the
  human-gate hooks; "no human required" is simply the state where the planner's
  emit path is allowed and guarding is procedural.
- The guard-rails (cost, resource, evidence-check, priority steering) are what
  make "no human required" safe; until those are robust, dispatch stays
  human-gated by default (startable, not required to start).
- Near-term: this agent (Hermes) configures and launches squads (`hngh up`,
  `planner-cycle --emit`); later Hngh surfaces its own interface (steer,
  observe, dispatch-intent panels).

---

## 7. Prioritized roadmap (waves)

| Wave | Scope | Gating | Deliverables |
|---|---|---|---|
| **L1** | Observation first: hngh-mc observes squads + TUI peep depth | mission-control, dashboard | `observe <squad>`, squad wall, depth views |
| **L2** | Procedural guard-rails: evidence-check + guard-loop-pass + escalate | task-driver, signals | claim cross-checking, multi-pass dev/review, bounded retries |
| **L3** | Steering primitive: priority router + `hngh-steer` plugin | signals, live surfaces | score/rank situations, Hermes /steer, opencode pause-correction |
| **L4** | Hermes + opencode integration plugins | L3 | full obverse/steer/param end-points |
| **L5** | Self-steering + continual param optimization | C8/C9 datasets | shadow-then-promote optimizer over params + strategies |

Ordering rationale (eases later work): **L1 first** because observation is how
humans verify everything else; **L2** makes auto-work safe; **L3** makes it
steerable live; **L4** connects it to the running tools; **L5** closes the
"tune itself to emerging circumstances" loop.

---

## 8. What this is NOT (scope guard)

- Not a replacement for human review — Hngh watches, humans verify at depth.
- Not an auto-executor of high-impact/irreversible actions — human remains
  the gate where the rubric says so.
- Not post-hoc logging — that exists; this is the live/underway layer on top.
- The param-optimization and steering *prime movers* wait for C8/C9 data +
  the primitive; the surfaces and guard-rails are the near-term build.

## Attribution
Design capture for Hngh (owner brief: live orchestration, observation,
steering, guard-rails, param optimization, Hermes/opencode plugins).
Orchestrated by deepseek-v4-flash-0731 via openrouter (Hermes TUI).
