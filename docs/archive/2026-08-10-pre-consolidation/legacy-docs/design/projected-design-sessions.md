# Projected Design Sessions — Squad Automation Waves 2-9

**Status**: Staged (2026-08-03) — loose structures for expansion
**Author**: PM (z-ai/glm-5.2, Hermes harness)
**Depends on**: `docs/design/squad-startup-automation.md` (design doc), `docs/design/beans-aesthetic.md` (beans riff)

## How to read this

Each session is a loose structure: who participates, what they produce, what
they depend on, what the next session needs from this one. Expand and fill as
roles pick them up. The PM dispatches; the Designer decomposes; the roles
coordinate. Sessions are not rigid — roles can combine sessions if the work
is small enough, or split them if it grows.

Precondition gates apply: a session doesn't start until its preconditions
are met (checked at dispatch time, no LLM).

---

## Session D2: File-Change Notification Design

**Wave**: 2 (bean bus — the comm-line everything builds on)
**Participants**: Designer (lead), Coder (consult), Accountant (cost review)
**Preconditions**: config-watcher.lisp exists and exports init/shutdown/running-p/status; event-bus:publish callable from plugins
**Produces**:
- `docs/design/file-watcher.md` — plugin API spec:
  - `register-path` / `deregister-path` function signatures
  - `file.changed` event payload format (path, diff summary, timestamp, source)
  - Registration scoping (per-role path registration)
  - Systemd `.path` unit generation spec (gbd pattern — `PathChanged=` lines)
  - mtime-poll fallback spec (when inotify unavailable)
  - Debounce behavior (reuse config-watcher's pattern)
  - Thread safety (background watch thread, like config-watcher)
- Test fixture spec: synthetic file, register watch, touch file, assert event, deregister, assert no event
**Coder consults on**: existing plugin patterns, hngh.asd registration, package exports
**Accountant reviews**: cost of systemd unit generation vs mtime-poll only; VRAM impact (should be zero — no model involved)
**Next session needs**: working file-watcher plugin (Wave 2 implementation) before Wave 3

**Implementation**: Coder builds from spec. PM verifies with `make test`. Touch only: `src/plugins/file-watcher.lisp` (new), `src/packages.lisp`, `hngh.asd`, `tests/unit/test-file-watcher.lisp`.

---

## Session D3: Dispatch Tree + Git-Backed State Design

**Wave**: 3 (dispatch tree + atomic rollback)
**Participants**: Designer (lead), Accountant (git history audit spec), Coder (consult)
**Preconditions**: file-watcher plugin exists (Wave 2 done); `generate-pm-prompt` exists (Wave 1 done)
**Produces**:
- `docs/design/dispatch-tree.md` — spec:
  - Directory structure: `~/.hngh/squad/<name>/` with per-role inboxes, tasks/, journal/, state.git/
  - `dispatch.md` root index format (roles table, tasks table, communications table)
  - `create-squad` function: mkdir tree, git init, write initial dispatch.md, first commit
  - `plant-bean` function: write to inbox, git commit with structured message
  - `harvest-bean` function: read from inbox, mark as harvested in dispatch.md
  - `rollback-squad` function: `git checkout <sha>` in state.git
  - `get-squad-status` function: read dispatch.md, return plist
  - Precondition gate checking: `check-preconditions` reads spec, evaluates boolean expressions
  - Concurrent write policy: one writer per path (PM owns dispatch.md, each role owns its outbox)
- Accountant produces:
  - `docs/design/squad-audit.md` — husk audit spec:
    - How to read git log as squad action history
    - How to identify spoiled beans (dispatched but never harvested)
    - How to identify feral chains (spore beans that propagated beyond scope)
    - How to measure squad throughput (beans planted/harvested/digested per time window)
- Test fixture spec: create squad, plant bean, harvest, verify git log, rollback, verify state restored
**Coder consults on**: git operations from SBCL (uiop:run-program `git ...`), atomic file writes
**Next session needs**: working dispatch tree (Wave 3 implementation) before Wave 4

**Implementation**: Coder builds from spec. PM verifies. Touch only: `src/plugins/squad-dispatch.lisp` (new), `src/packages.lisp`, `hngh.asd`, `tests/unit/test-squad-dispatch.lisp`.

---

## Session D4: Bean Lifecycle Design

**Wave**: 4 (bean types, lifecycle, cross-role exchange)
**Participants**: Designer (lead), Artist (aesthetic integration), Accountant (husk audit), Coder (consult)
**Preconditions**: dispatch tree plugin exists (Wave 3 done)
**Produces**:
- `docs/design/beans-lifecycle.md` — spec:
  - Bean type definitions (message, task, status, resource, context, review, spore)
  - Bean file format (husk = markdown front matter, core = body, membrane = processing directives)
  - Lifecycle state machine: planted -> growing -> ripe -> harvested -> digested -> husked
  - Spoiled and feral states: detection, culling, notification
  - `plant-bean` (extended from D3): type-aware, writes bean-format file to inbox
  - `harvest-bean` (extended): type-aware, reads bean, marks harvested
  - `digest-bean`: role processes bean, produces output, writes husk to journal
  - `husk-bean`: writes journal entry with attribution
  - Cross-role exchange: any role can plant in any other role's inbox
  - Spore bean propagation: digesting a spore bean auto-generates sub-beans
  - Bean staleness detection: precondition re-check at harvest time
- Artist produces:
  - Bean vocabulary integration into squad prompts (per-role bean vernacular from beans-aesthetic.md)
  - TUI rendering concepts for bean status (pod fullness, staleness indicators)
  - ASCII art for dispatch tree visualization (beanstalk metaphor)
- Accountant produces:
  - Extended husk audit: per-bean-type throughput, spoilage rate, feral detection metrics
- Test fixture spec: full plant/harvest/digest/husk cycle per bean type, stale bean detection, spore propagation, culling
**Coder consults on**: file format parsing (markdown front matter), state machine implementation
**Next session needs**: working bean lifecycle (Wave 4 implementation) before Wave 5

**Implementation**: Coder builds from spec. Artist produces aesthetic assets. PM verifies. Touch only: `src/plugins/beans.lisp` (new), `src/packages.lisp`, `hngh.asd`, `tests/unit/test-beans.lisp`.

---

## Session D5: Prompt Matrix Design

**Wave**: 5 (skeleton-bones-flesh, per-role prompt generation)
**Participants**: Designer (lead), Artist (skeleton aesthetic), Coder (consult), Accountant (cost model)
**Preconditions**: generate-pm-prompt exists (Wave 1); beans plugin exists (Wave 4)
**Produces**:
- `docs/design/prompt-matrix.md` — spec:
  - Dimension table (role x scenario x strategy x resources x squad-count x roles-active x lifetime x directory x system x purpose)
  - Skeleton template library: 36 base skeletons (6 roles x 6 scenarios), each with labeled slots
  - Bone-filling procedures: per-slot deterministic fillers (AGENTS.md sections, plan summaries, system context, roadmap, OptMem, model assignment)
  - Flesh pass: LLM once-over spec — when to run (only if model is not local), how to prompt the flesh model, what to pass (assembled skeleton+bones), what to accept (edited prompt that preserves structure)
  - `generate-prompt` function: takes dimension values, selects skeleton, fills bones, optionally runs flesh pass
  - `select-role-model` function: per-role model assignment from the cost-optimized table, checking VRAM + budget + time-sensitivity
  - Per-role fallback chain evaluation: try primary, if 429/403 try next, if exhausted try local (if allowed for this role)
  - Prompt caching: if the same dimension combo produces the same prompt (deterministic bones), skip the flesh pass
- Artist produces:
  - Skeleton aesthetic: how prompts look (structure, headers, section order)
  - Bean vocabulary integration into prompt templates
- Accountant produces:
  - Cost model for flesh pass: per-role, per-scenario estimated token cost
  - Budget gate: when to skip flesh (budget exhausted, local model only)
- Test fixture spec: per-dimension value selection, skeleton structure assertion, bone-filling assertion, flesh-skip-when-local, flesh-skip-when-no-budget, model-selection-per-role
**Coder consults on**: existing generate-pm-prompt extension points, template engine approach
**Next session needs**: working prompt matrix (Wave 5 implementation) before Wave 6

**Implementation**: Coder builds from spec. PM verifies. Touch only: `src/plugins/hngh-up.lisp` (extend), `tests/unit/test-hngh-up.lisp` (extend).

---

## Session D6: Squad-Up Integration Design

**Wave**: 6 (wire procedural prompts into squad-up, replace static SEAT_PROMPT)
**Participants**: Designer (lead), Coder (implement), PM (review)
**Preconditions**: prompt matrix exists (Wave 5); dispatch tree exists (Wave 3); beans exist (Wave 4)
**Produces**:
- `docs/design/squad-up-integration.md` — spec:
  - `squad-up` modification: call `generate-prompt` per role instead of reading `SEAT_PROMPT[role]`
  - `squad-up --dry-run`: print all role prompts, show dispatch tree structure, show bean plant plan
  - `squad-up` creates dispatch tree on launch (calls `create-squad`)
  - `squad-up` plants startup beans in each role's inbox on launch
  - `squad-up --stop` triggers husking (calls `husk-squad`, writes fragment journals)
  - `squad-seats.conf` evolution: model assignments read from the cost-optimized table, not static SEAT_MODEL
  - `hngh up` integration: `hngh up` calls `squad-up` (or the same underlying function) instead of the old `squad` script
- Test fixture spec: `squad-up --dry-run` shows generated prompts for all roles, dispatch tree structure, bean plan
**PM reviews**: end-to-end flow, preconditions, attribution
**Next session needs**: working squad-up integration (Wave 6) before Wave 7

**Implementation**: Coder builds. Touch only: `~/.local/bin/squad-up` (extend), `~/.hngh-night/squad-seats.conf` (update), possibly `src/plugins/hngh-up.lisp` (extend launch-squad).

---

## Session D7: Self-Improvement Loop Design

**Wave**: 7 (C6 planner — roadmap scan, task decomposition, squad dispatch)
**Participants**: Designer (lead), PM (roadmap expertise), Accountant (resource projection), Coder (consult)
**Preconditions**: squad-up integration exists (Wave 6); dispatch tree exists (Wave 3); prompt matrix exists (Wave 5)
**Produces**:
- `docs/design/hngh-planner.md` — spec:
  - `scan-roadmap` function: reads `docs/project/roadmap.md`, identifies next unstarted wave
  - `decompose-wave` function: reads the wave's design doc, breaks into task specs
  - `dispatch-squad-for-wave` function: creates squad, generates per-role prompts, plants task beans, launches
  - `evaluate-completion` function: reads dispatch tree status, determines if wave is done (all tasks husked, tests green, docs updated)
  - `update-roadmap` function: updates roadmap.md wave status after completion
  - Spore bean for self-improvement: a spore that, when digested, triggers `scan-roadmap` -> `decompose-wave` -> `dispatch-squad-for-wave` autonomously
  - Human gate: PM reviews before autonomous dispatch (configurable: `:auto t` skips the gate)
- PM consults on: roadmap structure, what "next unstarted wave" means, how to detect blocked waves
- Accountant consults on: resource projection for the dispatched squad (VRAM, budget, time estimate)
- Test fixture spec: synthetic roadmap with wave statuses, decompose next wave, assert task specs generated, assert squad spec produced
**Next session needs**: working planner (Wave 7) before Wave 8

**Implementation**: Coder builds. Touch only: `src/plugins/hngh-planner.lisp` (new), `src/packages.lisp`, `hngh.asd`, `tests/unit/test-hngh-planner.lisp`.

---

## Session D8: Benchmark Squad Design

**Wave**: 8 (C8 — squads testing squads)
**Participants**: Designer (lead), Accountant (metrics spec), Artist (visualization), Coder (consult)
**Preconditions**: self-improvement loop exists (Wave 7); git-backed state exists (Wave 3)
**Produces**:
- `docs/design/benchmark-squad.md` — spec:
  - Benchmark squad strategy: a squad spec that runs another squad strategy and scores it
  - `clone-squad-state` function: clone the git repo at a specific sha
  - `vary-dimension` function: modify one prompt matrix dimension in the cloned state
  - `run-squad-against-state` function: dispatch a squad using the cloned/modified state
  - `score-squad-output` function: evaluate output quality (tests pass, doc completeness, time to completion, token cost)
  - `compare-runs` function: diff results across dimension variations
  - Benchmark artifact format: `~/.hngh/benchmarks/<date>-<strategy>-<dimension>.md`
- Accountant produces:
  - Metrics: test pass rate, time to first task completion, total token cost, husk quality score, spoilage rate
  - Comparison table format: dimension value x metric x score
- Artist produces:
  - Benchmark result visualization (ASCII table/graph for TUI)
- Test fixture spec: clone state, vary one dimension, assert score produced, compare two runs
**Next session needs**: working benchmark squad (Wave 8) before Wave 9

**Implementation**: Coder builds. Touch only: `src/plugins/benchmark.lisp` (new) or extend `hngh-planner.lisp`, `src/packages.lisp`, `hngh.asd`, `tests/unit/test-benchmark.lisp`.

---

## Session D9: Nightly Benchmark Cron Design

**Wave**: 9 (C9 — scheduled evidence-producing squads)
**Participants**: PM (lead), Designer (squad spec), Accountant (budget), Coder (implement)
**Preconditions**: benchmark squad exists (Wave 8)
**Produces**:
- `docs/design/nightly-benchmark.md` — spec:
  - Cron schedule: nightly at 02:00 (or configurable)
  - Cron prompt: "Clone hngh squad state, run benchmark squad against latest codebase, produce evidence artifact"
  - Evidence artifact: `~/.hngh/benchmarks/<date>-nightly.md` with metrics, comparison to previous nights, trend indicators
  - Budget gate: skip if daily budget exhausted
  - Notification: OptMem note when benchmark completes, deliver to PM via gateway if configured
  - Long-term dataset: artifacts accumulate, forming a time series for optimization
- PM specs: schedule, what to benchmark, what the evidence artifact should contain
- Accountant specs: budget allocation for nightly runs (should be $0 — local model + free tiers)
- Test fixture spec: cron fires, benchmark runs, artifact produced, OptMem note logged
**Implementation**: PM creates cronjob. Coder builds any supporting code if needed.

---

## Session Dependency Graph

```
D2 (file-change) ──────────────────────┐
                                       v
D3 (dispatch tree) ──────────────────> D4 (beans) ──> D5 (prompt matrix) ──> D6 (squad-up) ──> D7 (planner) ──> D8 (benchmark) ──> D9 (cron)
                                       │                 │
                                       │                 v
                                       │              D5a (Artist aesthetic)
                                       v
                                    D4a (Artist aesthetic)
```

D2 and D3 can start in parallel (no dependency between them). D4 depends on
D3. D5 depends on D1 (done) and D4. D6 depends on D3, D4, D5. D7 depends on
D6. D8 depends on D7 and D3. D9 depends on D8.

Artist sessions (D4a, D5a) can run in parallel with their parent sessions —
the Artist produces aesthetic assets while the Designer produces structural
specs. They merge at implementation time.

---

**Attribution**

PM — z-ai/glm-5.2 via openrouter, Hermes harness.
Designer — GLM-5.2 (sessions not yet started).
Artist — glm-5.2 or deepseek-v4-pro (sessions not yet started).
Coder — deepseek-v4-flash ($0.09/M) or gpt-5.6-luna ($0.10/M) (sessions not yet started).
Accountant — gemini-3.5-flash-lite ($0.30/M) (sessions not yet started).

Model assignments per `docs/design/model-pareto.md` — Pareto frontier,
per-role fallback chains, quota and budget gates. Each session should include
a model recommendation block with estimated token cost.
