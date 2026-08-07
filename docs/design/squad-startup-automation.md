# Squad Startup Automation — Dispatch Tree, Bean Bus, and Prompt Matrix

**Status**: Draft v0.1 (2026-08-03)
**Milestone**: M9 Wave 2-5 (extends squad-autonomy.md, hngh-up.md)
**Owner**: PM (this session, z-ai/glm-5.2 via openrouter)
**Inspirations**: gbd (systemd path units), beads (graph queue), Blame! (Nihei megastructure aesthetic), Agent Zero (hierarchical delegation)

---

## 1. The dispatch tree

Squad state lives in a directory tree under `~/.hngh/squad/<squad-name>/`. Every
role has an inbox, a task directory, and an outbox. The root index file is the
map the PM reads to see everything.

```
~/.hngh/squad/<squad-name>/
  dispatch.md              ← root index: roles, dependencies, status
  state.git/               ← git repo backing atomic rollback
  pm/
    inbox.md               ← messages addressed to PM
    outbox.md              ← messages from PM to others
    map.md                 ← PM's active map (rendered view of the tree)
  designer/
    inbox.md
    tasks/
      wave-2-file-watcher.md
      wave-3-journal.md
  coder/
    inbox.md
    tasks/
      task-84-implement-watcher.md
  worker/
    inbox.md
    tasks/
  accountant/
    inbox.md
    tasks/
  artist/
    inbox.md
    tasks/
  journal/
    projected.md           ← written at squad startup
    actual.md              ← updated on file-change events
    fragment.md            ← written at shutdown/pause
```

`dispatch.md` at the root is the index:

```markdown
# Squad: squad-automation-bootstrap

## Roles
| Role | Status | Model | Last seen |
|---|---|---|---|
| pm | active | glm-5.2 | 12:30 |
| designer | idle | glm-5.2 | 11:00 |
| coder | idle | free | 10:45 |

## Tasks
| ID | Title | Assigned | Status | Blocked by |
|---|---|---|---|---|
| w2 | file-change notification | designer | dispatched | — |
| w3 | journal lifecycle | designer | staged | w2 |
| t84 | implement watcher | coder | pending | w2-design |

## Communications
| From | To | Bean | Status |
|---|---|---|---|
| pm | designer | wave-2-design-request | planted |
| designer | pm | wave-2-design-complete | (pending) |
```

Each role on startup reads `dispatch.md`, finds its entry, traverses to its
inbox and tasks. The PM reads the whole tree. Tree traversal is O(log n) with
a balanced structure — `ls` and `cat` are the search primitives.

### Why a directory tree, not a database

Files are the comm-line. The file-change notification system (Wave 2) watches
these paths. When the PM writes to `designer/inbox.md`, the Designer gets a
`file.changed` event. That's the squad comm-line — files are messages, events
are notifications. A database would require a separate query interface and
wouldn't integrate with the existing event bus or systemd path units.

### Why not a single flat file

A single dispatch file with 50 roles and 200 tasks is unreadable. A tree where
each level has a small index scales to any depth. The PM can zoom in on one
subtree or zoom out to the root.

---

## 2. Precondition gates

Every staged spec declares what must be true for it to be valid. Checked at
dispatch time — no LLM involved, pure filesystem and symbol inspection.

```markdown
## Wave 2: File-change notification

Preconditions:
- generate-pm-prompt exists in hngh-up.lisp with signature (goal &key cwd lifetime squad-name model-config)
- config-watcher.lisp exports init/shutdown/running-p/status
- event-bus:publish is callable from plugins

Postconditions:
- file-watcher plugin registered in hngh.asd
- file.changed events emitted on registered paths
- make test green (new count: N+K)
```

If a precondition fails at dispatch time, the spec is marked invalid and the
PM is notified. The role never sees a stale spec. Preconditions are boolean
checks: `probe-file`, `find-symbol`, `fboundp`. Cheap, deterministic, no LLM.

### Staging depth rules

| What | How far to stage | Why |
|---|---|---|
| Design docs (requirements) | As far as you want | Declarations of intent, don't go stale unless requirements change |
| Implementation task specs | One wave ahead | Depend on accepted designs, reference specific files/signatures |
| Role prompts | At dispatch time | Depend on current state, generated procedurally by C7 |
| Bean exchanges | At dispatch time | Depend on role availability and current progress |

---

## 3. Git-backed atomic rollback

Squad state is a git repo at `~/.hngh/squad/<name>/state.git/`. Every PM
action (dispatch, assign, status update, bean plant) is a commit. Rollback
= `git checkout <sha>`. Benchmarking = clone the repo, replay against
different model configs, compare outputs.

### Commit granularity

One commit per PM action. Commit messages are structured:

```
[dispatch] pm -> designer: wave-2-design-request
[assign] pm -> coder: task-84 (blocked by: w2-design)
[status] designer: wave-2-design in-progress
[status] designer: wave-2-design done (artifact: docs/design/...)
[bean] pm -> coder: resource-bean (vram: 8192 MB)
[rollback] pm: undid dispatch task-84 (reason: precondition failed)
```

### What this gives us

- **Atomic rollback**: `git checkout <sha>` restores exact squad state
- **History**: `git log --oneline` is the full action log
- **Diff between any two points**: `git diff <sha1> <sha2>` shows what changed
- **Branching for what-if analysis**: `git checkout -b experiment-2`
- **Benchmarking**: clone the repo, run different model configs, compare
- **Replay**: reset to a point, re-dispatch with different parameters

### What it doesn't capture

Transient state — rate-limit retries, in-flight HTTP requests, agent context
windows. This is noise, not signal. The *decisions* and *assignments* are what
matter for benchmarking. Later (Wave 5+), an event log on top of the git layer
can capture finer granularity if needed.

---

## 4. Role senses — fast and slow, ephemeral and persisting

The inbox is the persisting channel. But roles should have *senses* —
awareness of changes in their environment without explicitly checking inbox.

### Sense layers

| Sense | Speed | Persistence | Mechanism | What it detects |
|---|---|---|---|---|
| **Inotify** | instant | ephemeral | systemd `.path` units / inotify | file changed in scope |
| **Event bus** | instant | ephemeral | `file.changed` events on bus | any registered path |
| **Inbox** | on-check | persisting | markdown files in dispatch tree | directed messages |
| **OptMem** | on-wake | persisting | shared memo notes | durable squad-wide facts |
| **Poll** | slow | ephemeral | mtime-poll fallback | file changed (no inotify) |
| **Heartbeat** | periodic | ephemeral | heartbeat files per role | role alive/stale |

### How roles "see" different things

Each role registers interest in paths within its scope. The file-change
notification system emits events only for registered paths. A role "sees"
changes to files it cares about and is blind to everything else.

```
PM scope:        everything (all paths under squad root)
Designer scope:  docs/design/, designer/inbox.md, designer/tasks/
Coder scope:     src/, coder/inbox.md, coder/tasks/
Artist scope:    docs/design/, artist/inbox.md, assets/
Accountant:     accountant/inbox.md, journal/, state.git/log
Worker:         worker/inbox.md, worker/tasks/, ~/.hngh-night/tasks/
```

### Fast vs slow

- **Fast (inotify/event bus)**: role A writes to role B's inbox → B gets
  `file.changed` event within milliseconds. This is the "tap on the shoulder."
  Ephemeral — the event fires once, then it's gone.
- **Slow (poll/heartbeat)**: if inotify is unavailable, mtime-poll every N
  seconds. Heartbeat files checked every 30s for liveness. This is the "walk
  around and check on things" mode.

### Ephemeral vs persisting

- **Ephemeral**: events, heartbeats. They fire and are forgotten. Good for
  real-time awareness, not for audit trails.
- **Persisting**: inbox messages, journal entries, git commits. They survive
  restarts and rollback. Good for decisions, assignments, audit.

A role's full awareness is the union: ephemeral events for "what just
happened" + persisting files for "what's the current state." The PM's active
map is built from both — events show recent activity, files show current
state, git log shows history.

### Low-resource ML for sense optimization

Sense registration can be learned. Track which events a role actually acts on
vs ignores. Over time, prune the registration list to the events that matter.
A simple frequency table (event type × role → action taken) is enough to start.
No model needed — just count and threshold.

---

## 5. Prompt matrix — procedural skeleton-bones

Static components used dynamically by procedure. The C7 generator fills in
who/what/where/when/why/how procedurally, then the cheapest available model
gives it a once-over for edits.

### Per-role model assignment

The model tier is not squad-wide. Each role gets the cheapest model that meets
its capability floor. The local model (gemma-4-12b) is assigned only to
non-time-sensitive procedural work — it can handle creative riffing, fixture
generation, and simple well-specified tasks, but it blocks on anything that
needs fast iteration or sound decision-making.

| Role | Primary (cost-optimized) | Capability floor | Local model use |
|---|---|---|---|
| PM | kimi-k2.6 ($0.60/M) or glm-5.2 (cheap) | coordination, delegation, review | never (decisions are time-sensitive) |
| Designer | glm-5.2 (cheap, strong instruction-following) | design decomposition, spec writing | creative riffing, aesthetic exploration only |
| Coder | deepseek-v4-flash ($0.09/M) or gpt-5.6-luna ($0.10/M) | code generation, TDD | simple well-specified tasks (fixture generation, mechanical edits) |
| Artist | gemini-3.6-flash (cheap, visual strength) or deepseek-v4-pro | visual design, ASCII art | never (creative quality matters) |
| Accountant | gemini-3.5-flash-lite (cheap, reliable) | cost tracking, resource audit | procedural counting, file scanning |
| Worker | deepseek-v4-flash ($0.09/M) | batch task execution | non-time-sensitive batch work, queued background tasks |

Fallback chains per role (cheapest capable -> next -> local):
- PM: glm-5.2 -> deepseek-v4-flash-0731 -> gpt-5.6-luna -> nemotron-3-ultra-550b-a55b:free -> local (never)
- Designer: glm-5.2 -> deepseek-v4-flash-0731 -> gpt-5.6-luna -> gemma-4-31b-it:free -> local (creative only)
- Coder: deepseek-v4-flash-0731 -> deepseek-v4-flash -> gpt-5.6-luna -> gpt-oss-20b:free -> laguna-s-2.1:free -> local (simple only)
- Artist: deepseek-v4-flash-0731 -> qwen3.7-flash -> gemma-4-31b-it:free (multimodal) -> local (never)
- Accountant: deepseek-v4-flash-0731 -> deepseek-v4-flash -> gpt-oss-20b:free -> local (procedural only)
- Worker: deepseek-v4-flash-0731 -> deepseek-v4-flash -> gemma-4-26b-a4b-it:free -> local (queued only)

### Model assignment in the startup flow

When `hngh up` or `squad-up` derives a squad spec:

1. The prompt matrix selects a skeleton per role x scenario.
2. The model assignment function (`select-role-model`) picks the primary model
   for each role from the table above, checking:
   - VRAM availability (resource gate, C2)
   - Budget remaining (llm-budget gate)
   - Time-sensitivity of the task (from the scenario dimension)
3. The model assignment becomes a resource bean planted in the role's inbox.
4. The prompt matrix uses the assigned model to determine whether the "flesh"
   LLM once-over runs (only if the assigned model is not the local model —
   local model doesn't edit its own prompts).

### Local model policy

The local model (gemma-4-12b via unsloth, $0) is:
- **Assigned** to: non-time-sensitive procedural work, fixture generation,
  creative riffing, simple well-specified tasks that don't need fast iteration
- **Never assigned** to: PM decisions, Artist creative output, anything
  time-sensitive, anything requiring sound architectural judgment
- **Fallback** for: Worker batch tasks (queued, not blocking), Accountant
  procedural counting (file scanning, test counting)
- **Blocking is acceptable** for: background batch work, creative exploration
  with no deadline, husk/journal writing
- **Blocking is not acceptable** for: squad startup, task dispatch, review
  verdicts, architectural decisions, anything on the critical path

The distinction is simple: if the task would be fine sitting in a queue for
30 seconds while the local model processes it, local is OK. If the task is
on the critical path and blocks other roles from working, use a remote model.

### Local-model queue — priority, ease, and indefinite deferral

Local-model tasks are not FIFO. They are ordered by priority and ease of
completion. A high-priority task that is hard gets deferred in favor of a
lower-priority task that is easy — the queue maximizes throughput of useful
work, not fairness. Tasks can be deferred semi-indefinitely: a research
thread that is low-priority and complex may sit in the queue for days,
periodically reassessed, while simple high-throughput tasks flow past it.

This makes the local-model queue a natural home for:
- **Research backlogs** — threads that are valuable but not urgent. The local
  model chews on them when nothing else demands its attention. Results
  accumulate as husks (journal entries) over time.
- **Procedural maintenance** — test-count lint, fixture regeneration, husk
  compaction. These are easy and can be batched.
- **Creative exploration** — aesthetic riffing, prompt skeleton drafts,
  alternative approach sketches. No deadline, no blocking.

The queue is a living backlog. Tasks are never discarded for age — they are
either completed, superseded (a later task makes them irrelevant), or
explicitly culled by the Accountant (feral/stale detection). Priority is
re-evaluated on each queue scan, so a task that was low-priority yesterday
can jump the line today if circumstances change.

### Skeleton dimensions

A prompt is assembled from a matrix of categorical dimensions. Each dimension
has discrete values. The generator selects values per dimension based on
context, then fills the template.

| Dimension | Values | Selected by |
|---|---|---|
| Role | pm, designer, coder, artist, accountant, worker | dispatch target |
| Scenario | startup, task-assign, status-check, review, shutdown, unblock | squad event |
| Strategy | duo-review, feature-sprint, design-fork, nightly-audit | squad type or saved strategy |
| Resources | local-only, budget-50, budget-200, unlimited | model tier + VRAM gate |
| Squad count | 1, 2, 3, 6, fanout-N | role layout |
| Roles active | subset of all roles | current dispatch tree state |
| Lifetime | ephemeral, continual, purpose-bounded | squad intent |
| Directory | repo path, AGENTS.md sections, plans, designs | working directory context |
| System | GPU, VRAM, local models, systemd units | resource-manager + model-runtime |
| Purpose | goal string | user input or planner decomposition |

### Skeleton → bones → flesh

1. **Skeleton**: the structural template for this combination of dimensions.
   Static, reusable, no context. Like a Mad Libs with labeled slots.
2. **Bones**: procedurally filled slots — AGENTS.md sections, plan summaries,
   system context, roadmap status, OptMem notes. Deterministic, no LLM.
3. **Flesh**: LLM once-over. The cheapest available model reads the assembled
   prompt and makes edits: tighten language, add missing context, fix tone.
   This is the only step that costs tokens.

### Skeleton categories

```
STARTUP-PM: orientation + context + intent + lifetime + coordination
STARTUP-DESIGNER: scope + design-request + dependencies + aesthetic
STARTUP-CODER: scope + task-spec + preconditions + file-list + conventions
STARTUP-ARTIST: scope + aesthetic-brief + visual-references + constraints
STARTUP-ACCOUNTANT: scope + cost-audit-request + resource-snapshot + budget
STARTUP-WORKER: scope + task-batch + preconditions + conventions

TASK-ASSIGN: task-id + title + files + acceptance-criteria + preconditions + attribution
STATUS-CHECK: role + last-seen + current-task + blockers + progress
REVIEW: artifact-path + review-criteria + severity-levels + verdict-format
SHUTDOWN: fragment-journal + resume-hint + value-captured + attribution
UNBLOCK: blocker-description + available-resources + suggested-paths
```

### Procedural construction (the "who, what, where, when, why, how")

The generator fills these procedurally before any LLM touches the prompt:

- **Who**: role name, model, provider, squad name
- **What**: task title, task ID, files to touch, acceptance criteria
- **Where**: working directory, repo root, AGENTS.md path
- **When**: squad timestamp, task deadline (if any), dependency status
- **Why**: squad intent, task purpose, how it fits the roadmap wave
- **How**: conventions (AGENTS.md), build/test commands, coordination protocol

Each is a string lookup or filesystem read. No inference, no generation. The
LLM once-over only edits for coherence and completeness — it doesn't create
content from scratch.

### Dimensional matrices for optimization

When prompts are categorically structured, we can optimize at any level:

- **Per scenario**: which startup prompt structure produces fastest task
  completion? (A/B test across squads)
- **Per role**: which model tier produces best output for each role?
- **Per strategy**: which squad layouts complete fastest within budget?
- **Per resource tier**: what's the minimum model that produces acceptable
  output for each role?

Git-backed state means we can clone, vary one dimension, replay, and compare.
The benchmark squad (Wave 5 C8) runs other squads and scores them.

---

## 6. Beans — the squad nutrient medium

Beans are Hngh-specific communication tokens. Squads eat beans. Beans carry
context, instructions, status, and resources between roles. They grow in pods
(inboxes), get harvested (dispatched), get digested (processed), and leave
husks (journals/fragments).

**Full aesthetic riff**: `docs/design/beans-aesthetic.md` — produced by
gemma-4-12b (local, $0, 22s). The Designer and Artist should incorporate this
vocabulary into squad prompts, TUI, and documentation.
**Model Pareto frontier**: `docs/design/model-pareto.md` — cost-optimized
model selection with per-role fallback chains, quota/budget gates, and
estimated cost per design session.

### Bean types

| Bean | Carries | Direction | Persistence |
|---|---|---|---|
| **Message bean** | directed text, instructions | role → role | persisting (inbox) |
| **Task bean** | task spec, files, acceptance criteria | pm → role | persisting (tasks/) |
| **Status bean** | progress, blocker, completion | role → pm | persisting (dispatch.md) |
| **Resource bean** | VRAM grant, model assignment, budget | pm → role | ephemeral (event) + persisting (dispatch.md) |
| **Context bean** | AGENTS.md sections, plan summaries, system state | any → any | ephemeral (event) + persisting (journal) |
| **Review bean** | verdict, annotations, corrections | reviewer → role | persisting (inbox) |

### Bean lifecycle

```
planted → growing → ripe → harvested → digested → husked
  (PM writes)  (in inbox)  (notified)  (role reads)  (role acts)  (journal entry)
```

- **Planted**: PM (or any role) writes a bean to a role's inbox
- **Growing**: bean sits in the inbox, file-change event fires
- **Ripe**: role's sense fires (inotify/event bus), role knows bean exists
- **Harvested**: role reads the bean from inbox
- **Digested**: role processes the bean — acts on instructions, produces output
- **Husked**: bean's content is recorded in the journal (the husk is the record
  of what was consumed, what it produced, what remains)

### Bean exchanges

Roles can plant beans for each other, not just PM → role:

- Designer → Coder: "here's the design, plant task beans in your inbox" (message bean + task bean)
- Coder → Accountant: "I need a cost projection for this model tier" (message bean)
- Accountant → PM: "budget projection attached" (status bean)
- Artist → Designer: "visual reference ready for review" (review bean)
- Worker → PM: "task batch complete, results in husk" (status bean)

### Nihei aesthetic integration

In the Blame! megastructure, the Silicon Life consume energy from the
Structure. Beans are the nutrient medium — the energy that flows through the
megastructure's conduits. Each bean is a packet of context-energy. Roles eat
beans to gain awareness. Empty pods (inboxes) mean starvation — the role has
nothing to work on. Husks (journals) are the organic residue of consumed
beans, left behind for the record.

The aesthetic vocabulary:
- "I'm hungry" = my inbox is empty
- "The PM planted beans" = new dispatch in my inbox
- "These beans are stale" = the spec is outdated, preconditions failed
- "I need fresh beans" = request new dispatch
- "Digesting" = processing a task
- "Husking" = writing the journal entry for completed work
- "Beanstalk" = the dispatch tree (the structure beans grow on)
- "Pod" = a role's inbox directory
- "Harvest" = reading dispatches
- "Crop" = a batch of beans planted together (a wave dispatch)

---

## 7. Squad journal lifecycle with beans

Journaling at three lifecycle points, wired into the bean lifecycle:

### Startup (planting)

`squad-up` or `hngh up` creates the dispatch tree, writes `journal/projected.md`
(first git commit), and plants startup beans in each role's inbox. The
projected journal records: goal, roles, models, planned work, timeline
estimate, bean types to be planted.

### Ongoing (growing, harvesting, digesting)

Roles harvest beans, digest them, and husk the results. The PM writes to
`journal/actual.md` triggered by file-change events on status beans. Each
digestion produces a husk entry: what bean was consumed, what was produced,
what remains, attribution.

### Shutdown/pause (husking)

`squad-up --stop` or the PM's pause directive triggers final husking. Each
role writes remaining work to `journal/fragment.md` (C5): unfinished beans,
resume hints, value captured. The PM makes the final git commit, preserving
the full squad state for rollback.

---

## 8. Self-improvement loop (Wave 5)

The recursive cycle: hngh reads its own roadmap → identifies the next unstarted
wave → decomposes into design requests → dispatches a squad → squad works on
hngh → results feed back into roadmap → repeat.

The beanstalk is the infrastructure. The PM plants design beans (Wave 2-5
requests). The Designer digests them and produces task beans. The Coder
harvests task beans and produces code. The Accountant tracks resource beans.
The Artist produces aesthetic beans. The husks (journals + git history) are
the benchmarking dataset.

### Benchmark squad (C8)

A squad strategy that runs other squad strategies and scores them. Clone the
git-backed state, vary one dimension (model tier, prompt structure, squad
layout), replay, compare outputs. The benchmark squad produces evidence
artifacts — not code changes, but measurements.

### Nightly benchmark cron (C9)

Scheduled squads that produce evidence artifacts. The cron fires a benchmark
squad against the latest codebase. Results accumulate in `~/.hngh/benchmarks/`.
Over time, this builds a dataset for optimizing prompt dimensions, model
selection, and squad layouts.

---

## 9. Implementation waves

| Wave | What | Files | Depends on | Status | Design session |
|---|---|---|---|---|---|
| 0 | Test-count lint | scripts/lint-test-counts.sh, Makefile | nothing | done | — |
| 1 | C7 PM-first-prompt generator | src/plugins/hngh-up.lisp | C1 (done) | done | — |
| 2 | File-change notification (bean bus) | src/plugins/file-watcher.lisp | config-watcher (done) | done (staged 03282f3, wired main.lisp) | D2 |
| 3 | Dispatch tree + git-backed state | src/plugins/squad-dispatch.lisp | Wave 2 | done (staged 03282f3, wired main.lisp) | D3 |
| 4 | Bean lifecycle (plant/harvest/digest/husk) | src/plugins/beans.lisp | Wave 3 | done (staged 03282f3, wired main.lisp) | D4 |
| 5 | Prompt matrix (skeleton-bones-flesh) | src/plugins/hngh-up.lisp (extend) | Wave 1, 4 | pending | D5 |
| 6 | squad-up integration | ~/.local/bin/squad-up | Wave 3, 5 | pending | D6 |
| 7 | Self-improvement loop (C6 planner) | src/plugins/hngh-planner.lisp (new) | Wave 3, 5, 6 | pending | D7 |
| 8 | Benchmark squad (C8) | squad spec, cron | Wave 7 | pending | D8 |
| 9 | Nightly benchmark cron (C9) | cronjob, squad spec | Wave 8 | pending | D9 |

**Projected design sessions**: `docs/design/projected-design-sessions.md` —
loose structures for D2-D9, each with participants, preconditions, deliverables,
and dependency graph. Expand and fill as roles pick them up.

### Wave 2: File-change notification (bean bus)

Generalize config-watcher into a registered-path file-change bus. Plugins
register interest in paths. Watcher emits `file.changed` events with path +
diff summary. For daemon mode: systemd `.path` units (gbd pattern). For local
mode: mtime-poll fallback.

**Files**: `src/plugins/file-watcher.lisp` (new), `src/packages.lisp`, `hngh.asd`,
`tests/unit/test-file-watcher.lisp`
**Preconditions**: config-watcher.lisp exports init/shutdown/running-p/status;
event-bus:publish is callable from plugins
**Acceptance**: Plugin registers interest in `docs/project/roadmap.md`. File is
touched. Event bus receives `file.changed` with the path. Roles subscribed to
the path receive the event. `make test` green.
**Tests**: fixture-based — synthetic file, registered watch, event assertion,
deregister, no-event-after-deregister.

### Wave 3: Dispatch tree + git-backed state

Create the dispatch tree structure, git init the state repo, implement
plant/harvest/digest/husk primitives as file operations with git commits.

**Files**: `src/plugins/squad-dispatch.lisp` (new), `src/packages.lisp`, `hngh.asd`,
`tests/unit/test-squad-dispatch.lisp`
**Preconditions**: file-watcher plugin exists (Wave 2)
**Acceptance**: `create-squad "test-squad"` creates directory tree with
dispatch.md, per-role inboxes, git repo. `plant-bean` writes to inbox and
commits. `git log` shows the action. `rollback-squad` checks out a prior sha.
`make test` green.
**Tests**: fixture-based — create squad, plant bean, harvest bean, verify git
history, rollback to prior state, verify state restored.

### Wave 4: Bean lifecycle

Implement bean types (message, task, status, resource, context, review),
lifecycle transitions (planted → growing → ripe → harvested → digested → husked),
and cross-role bean exchanges.

**Files**: `src/plugins/beans.lisp` (new), `src/packages.lisp`, `hngh.asd`,
`tests/unit/test-beans.lisp`
**Preconditions**: squad-dispatch plugin exists (Wave 3)
**Acceptance**: PM plants a task bean in Coder's inbox. Coder harvests it.
File-change event fires. Coder digests (produces output). Husk written to
journal. `make test` green.
**Tests**: fixture-based — plant/harvest/digest/husk cycle, stale bean
detection (precondition failure), bean type dispatch, cross-role exchange.

### Wave 5: Prompt matrix

Extend C7 generator with dimensional prompt construction. Skeleton templates
per dimension combination. Procedural bone-filling. Optional LLM flesh pass.

**Files**: `src/plugins/hngh-up.lisp` (extend), `tests/unit/test-hngh-up.lisp` (extend)
**Preconditions**: generate-pm-prompt exists (Wave 1), beans plugin exists (Wave 4)
**Acceptance**: `generate-prompt :role :coder :scenario :task-assign :strategy :feature-sprint`
produces a prompt with the right skeleton structure, procedurally filled bones,
and optionally an LLM-edited flesh layer. `make test` green.
**Tests**: fixture-based — per-dimension value selection, skeleton structure
assertion, bone-filling assertion, flesh-skip-when-no-budget assertion.

### Waves 6-9

squad-up integration, self-improvement planner, benchmark squad, nightly cron.
Depend on Waves 2-5 being stable. Design decomposed when those land.

---

## 10. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Staged specs go stale | Precondition gates checked at dispatch time |
| Git repo grows unbounded | Periodic compaction; husk-only journal after digestion |
| Bean bus too chatty | Sense registration pruning (low-resource ML: frequency table) |
| Prompt matrix combinatorial explosion | Start with 6 roles x 6 scenarios = 36 skeletons. Add dimensions as needed. |
| LLM flesh pass costs tokens | Only run when budget allows; skeleton+bones are usable without flesh |
| Concurrent file writes to dispatch tree | One writer per path (PM owns dispatch.md, each role owns its outbox) |
| Git operations block squad startup | Async git commit in background thread; squad starts immediately |

---

## Attribution

PM — z-ai/glm-5.2 via openrouter, Hermes harness.
Beans aesthetic riff — subagent (local gemma-4-12b or gemini-flash, TBD).
Designer — GLM-5.2 (review and decomposition pending).

## Related design docs

- `docs/design/squad-metabolism.md` — recursive design passes, avatar roles
  with stats/traits/senses, PM as background-brain project architect, Nihei
  megastructure aesthetic
- `docs/design/beans-aesthetic.md` — bean types, lifecycle, role vernacular
- `docs/design/model-pareto.md` — Pareto frontier, per-role model selection
- `docs/design/projected-design-sessions.md` — D2-D9 loose session structures
