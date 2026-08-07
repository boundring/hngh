# Squad Metabolism — Recursive Design Passes, Avatar Roles, and Omniscient Senses

**Status**: Draft v0.1 (2026-08-03)
**Milestone**: M9 (extends squad-startup-automation.md, beans-aesthetic.md, model-pareto.md)
**Author**: PM (z-ai/glm-5.2, Hermes harness)
**Aesthetic**: Tsutomu Nihei / Blame! megastructure. Self-expanding structure time. Light bean humor.

---

## 1. The PM as project architect

The PM is not a dispatcher who hands out tasks and waits. The PM is a
*project architect* who designs and redesigns the project itself as living
work. The project includes the squad's work — the designs, the plans, the
schedules, the decompositions — as its metabolism.

The PM participates with the other roles in a *background brain* capacity:
present in every conversation, sensing everything, but not directing every
word. The PM's job is to keep the project coherent while the roles work on
their parts. When something drifts, the PM notices — not by checking
everything, but by having senses that fire when patterns change.

### Background brain operation

The PM doesn't sit in every meeting. The PM has *senses* — file-change
notifications, event bus subscriptions, heartbeat monitors — that fire when
something relevant happens. The PM's awareness is the union of:

1. **Omniscient senses** (see section 3) — the PM sees everything by default
2. **Dispatch tree state** — current assignments, statuses, blockers
3. **Git history** — the action log, every dispatch and completion
4. **OptMem** — durable squad-wide notes

The PM intervenes when:
- A precondition gate fails (stale spec detected)
- A role goes stale (heartbeat dies, inbox spoils)
- A design conflict emerges (two roles produce contradictory specs)
- A budget gate fails (cost projection exceeds limits)
- A wave completes (roadmap update, next session dispatch)

Otherwise the PM stays in the background, redesigning the project as the
parts evolve.

---

## 2. Recursive design passes

Design is not one-pass. It's recursive: broad waves first, then focused
passes, then evolutionary redesign as parts mature and interact.

### Pass structure

| Pass | Scope | Granularity | Purpose | Roles |
|---|---|---|---|---|
| **Survey** | all waves | coarse | requirements research, landscape scan, option space mapping | PM + Designer |
| **Draft** | per wave | medium | first complete design, skeleton-bones, open questions | Designer + all consult |
| **Refinement** | per component | fine | focused design of parts, categorical aspects, interfaces | Designer + Coder + Artist |
| **Evolution** | per component | fine | redesign as implementation reveals constraints | Designer + Coder |
| **Integration** | cross-wave | medium | how parts connect, interface contracts, dependency verification | PM + Designer |
| **Retrospective** | completed wave | coarse | what worked, what didn't, husk analysis | PM + Accountant + all |

### How passes coincide

Passes don't happen sequentially. They overlap:

- Survey happens once, at the start, covering all waves (we just did this)
- Draft for wave N can start while Refinement for wave N-1 is running
- Evolution for wave N-2 can happen while Draft for wave N is starting
- Integration runs when two adjacent waves have drafts
- Retrospective runs after a wave is implemented and verified

This means at any given time, the squad might be:
- Surveying waves 7-9 (coarse)
- Drafting wave 4 (medium)
- Refining wave 3 components (fine)
- Evolving wave 2 parts (fine, as implementation proceeds)
- Integrating waves 2-3 (interface contracts)
- Retrospecting wave 1 (what we just finished)

### Strategic ordering

The PM can vary the approach to how work coincides and when it completes:

**Depth-first**: complete one wave fully (survey -> draft -> refine -> implement ->
evolve -> integrate -> retrospect) before starting the next. Safe but slow.
Good for high-uncertainty waves where early parts inform later parts.

**Breadth-first**: draft all waves first, then refine all, then implement all.
Fast parallelism, but integration risk is high — parts designed independently
may not fit together.

**Hybrid (recommended)**: survey all, draft 2-3 waves ahead, refine 1 wave
ahead, implement current wave, evolve the last wave. This is what the
projected design sessions (D2-D9) already structure — D2 and D3 can start
in parallel, D4 follows D3, etc.

**Critical-path**: identify the longest dependency chain and front-load it.
Defer non-critical work to slack periods. Good for time-constrained runs.

The PM chooses the strategy per squad, per goal. The prompt matrix
(`scenario` dimension) includes the strategy as a selectable value.

---

## 3. Omniscient senses — Hngh's purpose

> Hngh should be a system harness that gives agents and teams of agents and
> swarms of agents active senses they can use for experiencing and
> remembering the world and each other.

Senses are how roles experience the megastructure. Some are shared, some are
individual, plenty are categorical. A role's sense set is its *perceptual
horizon* — what it can perceive and what it cannot.

### Sense taxonomy

| Sense | Speed | Scope | Shared? | Mechanism |
|---|---|---|---|---|
| **Inotify** | instant | registered paths | individual | systemd `.path` / inotify |
| **Event bus** | instant | subscribed topics | shared | `file.changed`, `bean.planted`, `status.pulse` |
| **Inbox** | on-check | directed | individual | pod (inbox directory) |
| **Heartbeat** | periodic | per-role | shared | heartbeat files, liveness |
| **OptMem** | on-wake | squad-wide | shared | durable notes |
| **Git log** | on-query | full history | shared | `git log`, `git diff` |
| **Roadmap** | on-query | project state | shared | `docs/project/roadmap.md` |
| **Resource** | on-query | system | shared | VRAM, CPU, disk via resource-manager |
| **Budget** | on-query | financial | shared | `llm-budget`, OpenRouter credits |
| **Context pressure** | periodic | per-role | individual | token window usage |
| **Spoilage** | periodic | per-role inbox | individual | stale bean detection |
| **Presence** | event-driven | squad roster | shared | role online/offline/fallow |

### Per-role sense defaults

Each role gets a default sense set. The PM can expand or contract a role's
senses per squad. This is the RPG-like "class" system — your class determines
what you can perceive.

| Role | Default senses | Why |
|---|---|---|
| PM | all | omniscient by design — background brain |
| Designer | event bus, inbox, git log, roadmap, OptMem, resource | needs design context + project state |
| Coder | event bus, inbox, git log, resource, context pressure | needs code changes + resource limits |
| Artist | event bus, inbox, git log, OptMem | needs design direction + aesthetic context |
| Accountant | heartbeat, budget, git log, spoilage, OptMem | monitors squad health + cost |
| Worker | inbox, event bus, resource, context pressure | task-driven, resource-aware |

### Systemd watchers as rotating keywords

The PM's "background brain" uses systemd path units (gbd pattern) as
*rotating keyword sensors*. The PM registers keywords (file patterns, event
topics, status fields) and gets pinged when they appear in the environment.

For example: the PM registers `docs/design/*.md` as a watch path. When the
Designer writes a new design doc, the PM gets a `file.changed` event. The
PM doesn't read the doc immediately — it *senses* that something happened
and can choose to look closer or stay in the background.

This is the megastructure metaphor: the structure senses disturbances in its
own fabric. The PM is the structure's awareness. Roles are its inhabitants.

The table above is the *environmental + shared* sense set. The **social/
relational layer** — how agents perceive each other (signals/"emotes",
1:1 talks, message boards, relationship graph + rapport, and the procedural
thought-trace intent layer) — is captured separately in
[`docs/design/social-senses.md`](social-senses.md). The relational graph is
the social analog of the dispatch tree; rapport is the social analog of
`:experience` here (§4).

---

## 4. Avatar roles — stats, traits, and equipment

Roles are avatars. An avatar has stats, traits, personality, memories, senses,
tools, equipment, skills, abilities, inventory, and experience. This is not
decoration — it's a structured way to parameterize role behavior.

### Avatar stat block

```lisp
(avatar
  :role :pm
  :model "glm-5.2"
  :provider "openrouter"
  :cost-tier 4                      ; Pareto frontier position
  :stats (:intelligence 9           ; reasoning capability
          :coordination 10          ; delegation, routing
          :perception 10            ; sense range (omniscient)
          :endurance 7              ; context window size
          :speed 6                  ; response latency
          :creativity 5             ; novel idea generation
          :precision 8)             ; accuracy, attention to detail
  :traits (:background-brain        ; passive awareness, not active control
            :project-architect      ; designs the project, not just tasks
            :gatekeeper)            ; precondition and budget gates
  :senses (:all)                    ; sense set (see section 3)
  :skills (:design-session-projection
            :model-selection
            :precondition-gating
            :rollback
            :roadmap-scanning
            :cost-gating
            :fragment-recovery)
  :inventory (:dispatch-tree        ; owns the squad dispatch tree
              :git-history          ; owns rollback authority
              :budget-ledger)       ; owns the budget gate
  :experience 0                     ; increments per completed wave
  :memory (:short-term nil          ; current session context
           :long-term nil))         ; cross-session (OptMem + AGENTS.md)
```

### Stat meanings

| Stat | What it measures | Affected by |
|---|---|---|
| Intelligence | reasoning, planning, architectural judgment | model capability (Pareto Y-axis) |
| Coordination | delegation, routing, multi-role management | model capability + prompt structure |
| Perception | sense range, awareness of environment | registered senses, event subscriptions |
| Endurance | context window size, sustained work capacity | model context length |
| Speed | response latency, time-to-first-token | model latency, provider load |
| Creativity | novel idea generation, aesthetic exploration | model capability + temperature |
| Precision | accuracy, attention to detail, test-writing | model capability + prompt specificity |

### How stats affect behavior

Stats are not cosmetic. They parameterize role behavior:

- **Intelligence < 7**: cannot be PM or Designer. Assigned to Worker or
  Accountant procedural tasks.
- **Perception = :all**: PM only. Other roles get scoped perception.
- **Endurance < 200K**: cannot handle large-context tasks (reading full
  design docs). Assigned smaller, focused tasks.
- **Speed < threshold**: not assigned to time-critical scenarios (squad
  startup, unblocking).
- **Creativity > 7**: eligible for Artist, creative exploration tasks.
- **Precision < 7**: must have PM review pass on output.

### Stat combinations as characteristics

Specific stat combinations define *characteristics* — behavioral patterns
that emerge from the stats rather than being explicitly programmed:

| Characteristic | Stat combo | Behavior |
|---|---|---|
| Background brain | high perception, high intelligence, low speed | senses everything, acts rarely, high-quality interventions |
| Front-line coordinator | high speed, high coordination, medium intelligence | fast routing, delegation, keeps squad moving |
| Deep diver | high intelligence, high endurance, low speed | takes complex tasks, works long, produces thorough output |
| Scout | high speed, high perception, low endurance | quick surveys, landscape scans, option mapping |
| Mason | high precision, medium intelligence, high endurance | careful implementation, thorough tests, reliable output |
| Fermenter | high creativity, high intelligence, low precision | produces designs, not code; ideation over correctness |

A role's characteristic emerges from its model assignment + prompt structure
+ stat block. The PM can tune characteristics by swapping models, adjusting
prompts, or expanding sense registrations.

### Experience and leveling

Avatar experience increments per completed wave. Higher experience unlocks:

- More autonomy (fewer PM review passes needed)
- Larger task scope (more complex specs can be dispatched directly)
- Sense expansion (more event subscriptions, broader perception)
- Budget authority (can dispatch sub-tasks within a budget allocation)

This is not gamification for its own sake. Experience is a *trust signal* —
a role that has successfully completed N waves gets more autonomy, which
reduces PM overhead. The PM's background brain doesn't need to watch
experienced roles as closely.

---

## 5. Nihei aesthetic — self-expanding megastructure time

In Blame!, the megastructure expands autonomously, layering new strata over
old ones without central control. The expansion is not planned — it's
emergent, driven by local processes that each follow simple rules.

Hngh's self-improvement loop is the same pattern. Each squad that works on
hngh adds a stratum to the megastructure. The structure doesn't know what
it will become — it just keeps growing. The PM's job is not to plan the
final form, but to keep the expansion coherent: prevent feral growth, cull
spoilage, ensure each new stratum connects to the ones below it.

### Light bean humor

> A Safeguard walks into a pod. The pod is empty. "I'm starving," says the
> Safeguard. The megastructure does not respond. It never responds. But
> somewhere in the root system, a bean begins to grow.

The humor is Nihei's: deadpan, structural, biological-meets-machine. The
megastructure is absurd — it's a building that eats people, and the people
are fine with it because the building is also their food. Hngh squads eat
beans that the structure grows. The structure grows because the squads
build it. The cycle is the joke.

### Megastructure time

Megastructure time is not human time. Layers form over geological scales
in Blame!, but each layer is built in moments by autonomous systems. Hngh's
wave progression is the same: each wave takes hours to implement, but the
structure they build persists across sessions, squads, and weeks. The PM
operates on megastructure time — not rushing the next wave, but ensuring
each layer is sound before the next one forms on top of it.

---

## 6. Complete design before parts

> There are many things that should get a *complete* design before their
> parts are considered, and it's normal for those to get considerable
> redesign as part of completion.

The recursive pass structure (section 2) handles this. A wave gets a
*complete* design in the Draft pass — all components, all interfaces, all
edge cases. Then the Refinement pass breaks it into parts and designs each
in detail. Then Evolution redesigns as implementation reveals constraints.

The key rule: **the complete design is the target, not the constraint.**
Parts are designed against the complete design, but the complete design is
allowed to change when a part reveals a flaw. This is why git-backed
rollback matters — you can roll back to the original design, compare with
the evolved version, and choose.

### When redesign is expected

| Trigger | What redesigns | Who |
|---|---|---|
| Implementation reveals API mismatch | the interface, not the architecture | Designer + Coder |
| Two parts can't connect | the interface contract, not the parts | Designer |
| A part is harder than expected | the decomposition, not the goal | PM + Designer |
| A dependency changes | the dependent part's interface | Coder + Designer |
| A new requirement emerges | the affected component + its interfaces | PM + Designer |
| Benchmark data shows a model is weaker than expected | model assignment for affected roles | PM + Accountant |

---

## 7. Application to current task: squad designs D2-D9

We are in the Survey pass for D2-D9 (done — the projected design sessions
are the survey output). The next pass is Draft per wave.

### Draft pass for D2 (file-change notification)

The Designer produces a complete design for the file-watcher plugin:
API, event format, path registration, systemd unit generation, mtime-poll
fallback, debounce, thread safety, test fixtures. All components, all
interfaces, all edge cases. The Designer consults with:
- Coder: existing plugin patterns, hngh.asd registration
- Accountant: cost of systemd generation vs poll-only
- Artist: TUI rendering of file-change events (sense visualization)
- PM: integration with dispatch tree (D3) and beans (D4)

### Draft pass for D3 (dispatch tree)

Parallel with D2. The Designer produces a complete design for the dispatch
tree: directory structure, dispatch.md format, git operations, create/plant/
harvest/rollback functions, precondition checking, concurrent write policy.
Consults with:
- Accountant: husk audit spec (git log as action history)
- Coder: git operations from SBCL
- PM: integration with beans (D4) and prompt matrix (D5)

### How the squad works on this

1. PM dispatches D2 Draft and D3 Draft to Designer in parallel (preconditions met)
2. Designer ferments both, produces complete specs, plants implementation beans
3. Coder harvests implementation beans, starts on whichever is ready first
4. Artist produces sense visualization concepts for D2, dispatch tree rendering for D3
5. Accountant audits cost projections for both implementations
6. PM stays in background, senses progress via file-change events, intervenes only on conflicts or gate failures
7. As D2 and D3 complete, PM dispatches D4 Draft (preconditions: D2 + D3 done)
8. The cycle continues: Draft -> Refine -> Implement -> Evolve -> Integrate -> Retrospect

### Ralphing until stopped

The PM keeps dispatching the next pass for the next wave until:
- All waves are designed and implemented
- A precondition gate fails that the PM cannot resolve (escalate to owner)
- The budget gate fails (all models exhausted, including free tier)
- The owner stops the squad

Each pass produces husks (journals, git commits). The husks are the
benchmarking dataset. The retrospective pass analyzes them for the next
iteration.

---

## 8. Attribution

PM — z-ai/glm-5.2 via openrouter, Hermes harness.
Concept — user (owner), 2026-08-03.
