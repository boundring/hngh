# Squad Autonomy — Self-Orienting, Resource-Aware, Self-Continuing Squads

**Status**: Draft v0.1 (2026-08-02)
**Milestone**: M9 (extends agent-platoons.md, hngh-up.md)
**Owner**: PM (this session, kimi-k3 via kimi-coding)

---

## 1. Why this doc

Prior work gave us three primitives in isolation:

- `agent-platoons.md` — declarative squad specs, tmux launch, journaling
- `hngh-up.md` — procedural questionnaire → spec derivation → launch
- `core/resource-manager.lisp` — VRAM/CPU/memory grants with preemption (exists, unused by squads)

None of them talk to each other yet, and none of them close the loop: hngh
still needs a human to notice a roadmap gap, write a goal string, and answer
(or default through) a questionnaire every time. The user's ask is to make
that loop recursive — hngh watches its own roadmap and AGENTS.md files,
decomposes work, queues it, and squads self-orient, self-launch, and
self-continue against it, with resource and cost limits as first-class
inputs, and squads' own operational history as the training data.

This doc designs seven capabilities as one system. Each capability is
independently shippable; together they are the "squad-oriented automatic
project management" portfolio piece.

---

## 2. Capability map

| # | Capability | Extends | New surface |
|---|---|---|---|
| C1 | AGENTS.md-oriented squad context | hngh-up context gathering | per-directory AGENTS.md discovery/merge |
| C2 | Resource-aware squad sizing | resource-manager grants | squad spec preflight gate on resource-manager, not just systemd |
| C3 | Procedural questionnaire from AGENTS.md | hngh-up questionnaire | AGENTS.md becomes the primary inference source, not one signal among many |
| C4 | Start-now, pause-on-cause | mission-control forward-prompt | squads launch immediately at creation; pause is an explicit event, not a default |
| C5 | Hills-to-die-on / fragment breadcrumbing | journal (projected/actual) | a third journal artifact: `-fragment.md` for unfinished-but-valuable work |
| C6 | Recursive plan → task → squad cycle | roadmap.md, work-sessions.md | `hngh-planner` plugin: roadmap scan → task decomposition → queue → squad dispatch |
| C7 | Self-written first prompts | mission-control wake templates | replace static `wake-template` strings with a generator keyed on task+session+resources |
| C8 | Squads testing squads | night-ralph / day-queue specs | a benchmark squad strategy that runs other squad strategies and scores them |
| C9 | Nightly benchmark/optimization cron | cronjob (Hermes), squad specs | scheduled squads that produce evidence artifacts, not just code changes |

---

## 3. C1 — AGENTS.md-oriented squad context

### Discovery

```lisp
(defun discover-agents-md (start-dir)
  "Walk from START-DIR to filesystem root, collecting every AGENTS.md found.
Nearest-first order (start-dir's own AGENTS.md is highest priority)."
  (loop for dir = (truename start-dir) then (parent dir)
        while dir
        for f = (merge-pathnames "AGENTS.md" dir)
        when (probe-file f) collect f
        until (root-p dir)))
```

Squads are not global — a squad spun up in `~/Projects/etc/hngh/src/plugins/`
should read that directory's AGENTS.md if one exists, then hngh's own
top-level AGENTS.md, then any machine-wide coordination contract
(`~/.hermes/AGENTS.md` equivalent, if the user adds one). Merge order:
nearest wins on conflict, but sections are additive (a subdirectory
AGENTS.md doesn't have to restate the memo/attribution contract).

### Context extraction from AGENTS.md

AGENTS.md is unstructured prose today by convention (Markdown, human-first).
Rather than impose a schema, extract signal procedurally:

- Section headers → topic list (`## Coordination contract`, `## Repo notes`)
- Fenced code blocks → literal commands the squad should know (`make test`)
- "Current state" section → freshness signal (last-updated date, test count)
- Any line matching `^- \*\*(\w[\w -]*)\*\*:` → key facts as an alist

This feeds the questionnaire (C3) and the resource-aware sizing (C2)
directly — no separate config format to maintain per-project.

---

## 4. C2 — Resource-aware squad sizing

`core/resource-manager.lisp` already tracks VRAM/CPU/memory via grants with
priority and preemption. Squads currently ignore it — `require-systemd` in
preflight only checks the unit is active, not whether it has headroom.

### New preflight gate: `resource-gate`

```lisp
(resource-gate
  :vram-mb-per-member 6000     ; estimate per local-model member
  :max-members-if-shared 2     ; cap fireteam size if VRAM is contended
  :fallback-tier :budget-50)   ; if VRAM insufficient, downgrade model tier
```

At spec-derivation time (hngh-up or the planner), before writing the spec:

1. Call `hngh.core.resource-manager:hardware-info` for VRAM free.
2. Estimate cost per member from the model tier's model sizes (a static
   table: gemma-4-12b ≈ 6-8GB, Qwythos-9B ≈ 10-12GB, remote = 0 local VRAM).
3. If `(* member-count vram-per-member) > vram-free`, either:
   - reduce squad size (drop the `:reviewer` role and let the coordinator
     self-review), or
   - fall back to a lower model tier / remote (with quota-gate check first)
4. Reject creation (not silently degrade) if even one coordinator can't fit
   and no remote budget exists — write a blocker to the journal fragment
   (C5), don't hang.

### Grant lifecycle tied to squad lifecycle

Each squad member that spawns a local model runtime should acquire a
resource-manager grant (`:kind :vram`, `:holder "squad:<name>:<role>"`,
`:preemptible t` unless the continuation policy is `:full-auto`). Squad
teardown (or mission-control's session-alive-p going false) releases the
grant. This makes squads visible to `resource-manager:list-grants` the same
way any other VRAM consumer is, and lets preemption reclaim VRAM from a
paused squad for a higher-priority one.

### Quota/rate limits

`llm-budget` already gates remote spend. Extend the same pattern for local
rate: track local-model requests/min per squad member (already loggable via
model-runtime call counters) and add a `:rate-limit-per-min` preflight gate
so an overzealous squad doesn't starve the shared unsloth-studio endpoint
for other squads or the user's own interactive session.

---

## 5. C3 — Procedural questionnaire from AGENTS.md

Today's questionnaire (hngh-up.md §3) infers from five context sources with
AGENTS.md as one signal among several. Flip the priority: AGENTS.md (C1's
merged, nearest-first stack) becomes the primary source, with goal text and
system context as fallback/override.

### Answerability rule

A question is skipped entirely (auto-answered, not defaulted) if AGENTS.md
supplies a direct answer:

| Question | AGENTS.md signal that answers it | 
|---|---|
| Squad layout | "Repo notes" mentions "coordinator", "PM", "review" pattern → infer type |
| Model tier | "Local-model & quota policy" section present → use its stated daily driver + spend cap verbatim |
| Continue policy | "Current state" freshness (< 1 day old) → `:token-aware`; stale (> 7 days) → `:manual` (needs human eyes first) |
| Journal detail | "Doc convention" section present → match its verbosity convention |

Only questions AGENTS.md cannot answer surface to the human (or, in
automatic mode from the planner, get a documented default with the
reasoning logged to the journal — never silently guessed).

This is the mechanism that makes "questions easily answered with any given
AGENTS.md" concrete: it's not NLP, it's grep-shaped extraction against
known section headers plus a small number of hand-written inference rules,
extendable per-project without code changes (AGENTS.md is the config).

---

## 6. C4 — Start-now, pause-on-cause

Current default (hngh-up.md §2) is `--interactive` questionnaire before
launch, `:manual` continuation, tmux attended by default. Flip the defaults:

- **Launch is the default action of creation.** `hngh up <goal>` (no flags)
  should derive a spec and call `squad up` immediately, using AGENTS.md
  answerability (C3) to skip the questionnaire whenever it can. Interactive
  questionnaire becomes an opt-in (`--interactive`), not the default.
- **Pause is an explicit event, not an idle state.** A squad only pauses
  when one of:
  - `llm-budget` crosses the configured threshold (existing continuation
    protocol)
  - resource-gate reports VRAM/rate pressure requiring preemption
  - the coordinator or reviewer emits an explicit `(:pause :reason ...)`
    journal event (self-reported blocker — a beads-style status)
  - a human sends an explicit stop (`hngh-client squad pause <name>`)
- **No default idle timeout.** Squads that are making progress (journal
  entries advancing, files changing) keep running until one of the above
  fires. This is the "permitted to extend their work and lifespan" ask —
  remove the artificial ceiling, replace it with real signals.

---

## 7. C5 — Hills-to-die-on / fragment breadcrumbing

Extend the two-file journal convention (`-projected.md` / `-actual.md`,
agent-platoons.md §2) with a third:

```
hngh/journal/squads/<name>-<timestamp>-fragment.md
```

Written when a squad pauses or is torn down with work in flight that:
1. Cannot be completed in the remaining budget/turns, but
2. Represents a concrete, valuable, reviewable unit (a passing test, a
   working prototype, a design decision with rationale) — not scratch work.

### Fragment format

```markdown
# Fragment: <squad-name> — <what this piece is>

**State**: incomplete — <one-line reason: budget exhausted / VRAM preempted / turn cap>
**Value**: <why this is worth keeping even unfinished>
**Location**: <files/branches/commits this fragment touches>
**Resume hint**: <the single most useful next action for whoever picks this up>
**Attribution**: <role — model, harness, cost>
```

Fragments are discoverable the same way sessions are — `session_search`-style
grep over `hngh/journal/squads/*-fragment.md` — and the planner (C6) should
scan them before decomposing new work, so half-finished hills don't get
silently duplicated or lost.

---

## 8. C6 — Recursive plan → task → squad cycle

New plugin: `src/plugins/hngh-planner.lisp`.

### Cycle

```
roadmap.md + AGENTS.md + journal fragments + prior benchmark results
        │
        ▼
  [gap analysis]  — what's stale, unstarted, or blocked?
        │
        ▼
  [task decomposition] — break gaps into work-session-sized units
        │
        ▼
  [weighting] — priority × confidence × resource cost, using prior
                benchmark results (C8/C9) as the confidence signal
        │
        ▼
  [work schedule] — ordered queue of tasks, each tagged with a
                     recommended squad strategy
        │
        ▼
  [dispatch] — hngh-up derives + launches a squad per queued task,
               respecting resource-gate (C2) for how many run concurrently
        │
        ▼
  [squads work, journal, possibly fragment (C5)]
        │
        ▼
  [planner re-scans] — fragments and actuals feed back into gap analysis
```

This is a closed loop, not a one-shot planner. The existing task queue
(`~/.hngh/tasks/queue.lisp`, per `docs/project/next.md`) is the substrate;
`hngh-planner` is the producer that keeps it filled from roadmap analysis
instead of a human writing task files by hand.

### Weighting inputs (concrete, not vibes)

- **Priority**: explicit roadmap milestone ordering (M-numbers) plus
  "blocked" flags already in roadmap.md's table format
- **Confidence**: pass/fail rate of prior squads run against similar task
  shape (tracked by C8's benchmark squad)
- **Resource cost**: estimated VRAM-minutes + remote-cents from prior
  actuals for tasks tagged with the same strategy

Gap analysis and weighting are procedural (rule-based scoring over
structured fields), not an LLM call — keeps this cheap enough to run
every cycle without burning budget on the planning step itself.

---

## 9. C7 — Self-written first prompts

Current wake templates (`coordinator-base`, `worker-base`, `reviewer-base`)
are static strings interpolated with role/goal. Replace with a generator:

```lisp
(defun generate-wake-prompt (member task work-session project resources)
  "Procedurally compose a first prompt from TASK's decomposed shape,
WORK-SESSION context, PROJECT's AGENTS.md-derived facts, and RESOURCES
(budget/VRAM headroom) — not a fixed template with blanks filled in."
  ...)
```

Inputs available at generation time (all already produced upstream in this
design): the task's decomposition unit (C6), the AGENTS.md merge (C1), the
resource envelope (C2), and — if this member is one of several — the other
members' roles, so a worker's prompt can reference "the reviewer will check
X" without a human writing that cross-reference by hand.

### Delivery: parallel vs serial

- **Parallel** (default for `:squad`/`:organism` layouts): all members'
  prompts are generated up front from the same task/session snapshot and
  submitted the moment each pane comes up — no round-trip waiting.
- **Serial** (for `:hierarchy` layouts, or when a role's prompt depends on
  another's first output): the coordinator's prompt goes first; downstream
  roles' prompts are generated after the coordinator's first response lands
  (so a worker's prompt can include "here's what the lead decided").

This is a strategy flag on the squad spec (`:prompt-delivery :parallel` /
`:serial`), not a hardcoded behavior — different layouts want different
defaults, and a strategy can override.

---

## 10. C8 — Squads testing squads

A new built-in strategy: `benchmark-runner`. Its job is to launch other
squad strategies under controlled conditions and score them.

```lisp
(strategy
  :name "benchmark-runner"
  :description "Runs N other squad strategies against a fixed task set, scores results"
  :members
  ((:role "harness" :cli "hermes" :model "local"
    :wake-template (generate-benchmark-harness-prompt))))
```

### What it measures (concrete, not just vibes)

- **Task completion rate**: did the squad reach `-actual.md` completion, or
  did it fragment (C5)? Fragmenting isn't failure — it's tracked separately
  from timing-out with nothing to show.
- **Cost per completed unit**: remote-cents + VRAM-minutes / completed tasks
- **Time-to-first-fragment**: how long before a squad produces its first
  reviewable artifact, regardless of full completion
- **Rework rate**: how often a squad's `-actual.md` gets contradicted or
  rewritten by a later squad touching the same area

Results write to a dataset, not just a log line — `hngh/benchmarks/<date>/results.jsonl`,
one row per squad run, schema: `{strategy, task-tag, model-tier, completion,
cost-cents, vram-minutes, time-to-fragment-s, rework-flag}`. This is the
evidentiary substrate the user asked for — a real dataset, not anecdotes.

---

## 11. C9 — Nightly benchmark/optimization cron

Wire `benchmark-runner` (C8) into a recurring Hermes cron job (not a squad
scheduling itself — Hermes cron is the outer clock, squads are the inner
workers, matching the existing night-ralph/day-queue split).

```
cronjob create --schedule "0 2 * * *" \
  --prompt "Run hngh benchmark-runner against the current task queue's
            5 oldest untried strategies. Local models only, $0 budget.
            Write results.jsonl. Report a 3-line summary, no raw logs."
```

### What comes out of this, concretely

- A growing `results.jsonl` — real data on which squad strategies perform
  best for which task shapes, at what cost
- A monthly rollup doc (`docs/project/benchmark-report-YYYY-MM.md`) —
  dated, categorized like a changelog, human-readable — that becomes
  citable evidence for a portfolio writeup or even a short paper: "we ran
  N squad-strategy combinations over M nights, here's what works"
- Feedback into C6's planner weighting (confidence input) — this closes
  the last loop: nightly benchmarks make next week's planner smarter.

---

## 12. Sequencing (wave-ordered, dependency-real)

| Wave | Ships | Depends on | Why this order |
|---|---|---|---|
| 1 | C1 (AGENTS.md discovery/merge) | nothing new | pure context-gathering, no launch-path risk |
| 1 | C5 (fragment journal) | agent-platoons journal (exists) | additive file format, no risk to existing flows |
| 2 | C3 (questionnaire from AGENTS.md) | C1 | needs the merged context to extract answers from |
| 2 | C2 (resource-gate) | resource-manager (exists) | independent of C1/C3, can build in parallel |
| 3 | C4 (start-now defaults) | C2, C3 | shouldn't flip launch defaults until sizing/answerability exist to make "start immediately" safe |
| 3 | C7 (self-written prompts) | C1, C6 (partial — task shape) | needs task decomposition to have something to compose from |
| 4 | C6 (planner cycle) | C1, C2, C3, C5 | the closed loop needs every upstream piece working first |
| 5 | C8 (benchmark-runner) | C4, C6 | needs real squads launching and completing/fragmenting to score |
| 5 | C9 (nightly cron) | C8 | needs the benchmark squad to exist before scheduling it |

Waves 1-2 are parallelizable across two squads/subagents right now. Waves
4-5 are the actual "hngh self-improving" milestone the user flagged —
everything before that is groundwork.

---

## 13. Acceptance criteria (per wave, zero further interview needed)

**Wave 1** (C1, C5):
- [ ] `discover-agents-md` returns nearest-first list of AGENTS.md paths for
      any given directory, unit-tested against a fixture tree with 3 nested
      AGENTS.md files
- [ ] Fragment journal writer produces valid Markdown matching the format
      in §7, callable from mission-control's pause path
- [ ] `make test` green with new tests added, no existing test broken

**Wave 2** (C3, C2):
- [ ] hngh-up questionnaire skips ≥ 3 of 5 questions when run against this
      repo's own AGENTS.md (self-test: `hngh up "test" --dry-run` shows
      auto-answered questions in output, not just defaults)
- [ ] resource-gate preflight rejects a squad spec when
      `(* member-count vram-per-member) > vram-free`, verified with a
      mocked hardware-info fixture (no real GPU pressure needed for the test)
- [ ] Grant acquire/release wired to squad launch/teardown, verified via
      `resource-manager:list-grants` before/after a squad lifecycle in tests

**Wave 3** (C4, C7):
- [ ] `hngh up <goal>` with no flags launches without questionnaire prompt
      when AGENTS.md answers everything (integration test)
- [ ] Pause only triggers on one of the four documented causes (budget,
      resource pressure, self-reported blocker, explicit human stop) —
      no idle-timeout code path exists post-change
- [ ] `generate-wake-prompt` produces distinct prompts for 2+ members given
      the same task, provably referencing cross-member context (unit test
      checks output contains other members' role names)

**Wave 4** (C6):
- [ ] `hngh-planner` scans roadmap.md + fragments, produces a queue of
      tagged tasks, all fields populated per §8's weighting inputs
      (no task enters the queue with a null priority/confidence/cost)
- [ ] Round-trip test: seed a stale roadmap item → planner surfaces it →
      dispatches a squad → squad completes → planner re-scan doesn't
      re-surface the same item

**Wave 5** (C8, C9):
- [ ] `benchmark-runner` strategy completes at least 3 runs against 3
      different existing strategies, writes valid `results.jsonl` rows
- [ ] Cron job created via `cronjob action=create`, `no_agent=false`,
      local-only budget, runs once successfully in a dry test before being
      left to the nightly schedule
- [ ] First `benchmark-report-*.md` rollup exists with real (not
      fabricated) numbers from at least one night's run

---

## 14. Open questions for the human (not blocking wave 1-2 start)

1. Should fragment journals (C5) auto-delete after N days if never picked
   up, or persist indefinitely as an append-only ledger? (Leaning:
   persist — cheap, and "breadcrumb" implies future discoverability.)
2. Should `benchmark-runner` (C8) results ever influence *live* squad
   dispatch (C6) automatically, or only after human review of the rollup?
   (Leaning: only after human review for the first few cycles — don't let
   a possibly-noisy benchmark silently change production routing.)
3. Portfolio/publication framing — is the target a blog post, a repo
   README section, or an actual short paper? Affects how rigorously C8's
   methodology needs to be documented (confidence intervals, sample size)
   versus just "here's what we found."

---

## 15. What this doc does NOT cover

- Social sharing of squad strategies (hngh-up.md §6 already designs this;
  out of scope here, no changes needed)
- Cross-machine/fleet squad coordination (M3 — Network milestone, not this
  cycle)
- Beads integration specifics — `docs/design/phase2-claim-release.md`
  already notes "no multi-agent bidirectional task queue (Beads-style)"
  as a known gap; C6's queue is deliberately simpler (a weighted list, not
  a full dependency graph) for this cycle. Revisit if C6's simpler queue
  proves insufficient once dogfooded.
