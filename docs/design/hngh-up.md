# hngh-up — Automated Squad Spin-Up with Procedural Questionnaire

**Status**: Draft v0.1 (2026-08-02)
**Milestone**: M1.15 (Integration) / M2 (Companion) boundary
**Owner**: PM (this session), implementation by Sisyphus

---

## 1. Why hngh-up?

Current state:
- `squad up <spec>` launches attended tmux sessions from declarative specs
- `squad validate` checks spec syntax without launching
- `squad status` shows tmux liveness
- First prompts are hand-written, sometimes long, sometimes short
- No automatic context-aware questionnaire before spin-up
- No "hngh-up" entry point — inconsistent with `squad-up` naming

Goal: **One command** that:
1. Gathers project/file/system context automatically
2. Generates a short, targeted questionnaire procedurally
3. Lets the user confirm/override (or skip with defaults)
4. Spawns the right squad with the right models/roles
5. Optionally continues managing token usage autonomously

---

## 2. Command Surface

```bash
# One-shot: spin up a squad for a goal
hngh up "Review all AGENTS.md files in ~/Projects/etc"

# Interactive: questionnaire first, then spin up
hngh up --interactive "Add tests for the new backup-manager plugin"

# Resume/continue an existing squad (if token management permits)
hngh up --continue squad-name

# List available squad strategies (built-in + user-shared)
hngh up --list-strategies

# Show questionnaire without spinning up (dry-run)
hngh up --dry-run "Refactor the threat-detection module"

# Spin up with a named strategy (shared configs)
hngh up --strategy duo-review "Review PR #42"
```

### Subcommands (extending `hngh-client`)

```
hngh up <goal> [options]
hngh up --list-strategies
hngh up --show-strategy <name>
hngh up --save-strategy <name> [--from-squad <squad-name>]
```

### Options

| Flag | Description |
|------|-------------|
| `-i, --interactive` | Run questionnaire before spin-up (default: true if TTY) |
| `-d, --dry-run` | Show questionnaire and derived spec, don't launch |
| `-c, --continue <squad>` | Resume/extend existing squad |
| `-s, --strategy <name>` | Use named squad strategy |
| `--list-strategies` | List built-in + user strategies |
| `--save-strategy <name>` | Save current run as reusable strategy |
| `--model-budget <cents>` | Override remote budget cap |
| `--local-only` | Force local models only (quota-gate: 0) |
| `--background` | Launch as background daemon squad (not attended tmux) |

---

## 3. Procedural Questionnaire Generation

The questionnaire is **not a fixed template** — it's generated from context:

### Context Sources (priority order)

1. **Goal text** — NLP-lite keyword extraction (task type, domain, scope)
2. **Project files** — `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `Makefile`, `pyproject.toml`, `Cargo.toml`, `go.mod`
3. **Hngh state** — `~/.hngh/config/`, `~/.hngh/state/`, `~/.hngh/journal/`
4. **System context** — GPU, local models running, systemd units, disk space
5. **OptMem** — `~/.optmem/memo wake` → recent notes, patterns
6. **Squad registry** — `data/squads.lisp` + `squads/*.spec`
6. **Shared strategies** — `~/.hngh/squad-strategies/` (user-shared configs)

### Questionnaire Structure (max 5 questions, adaptive)

```lisp
(questionnaire
  :goal "Review all AGENTS.md files in ~/Projects/etc"
  :detected-type :code-review
  :detected-scope :multi-project
  :questions
  ((:id :squad-type
    :prompt "Squad layout?"
    :options '((:squad "Fireteam: coordinator + workers + reviewer (default)")
               (:hierarchy "PM → devs, top-down")
               (:democratic "Consensus circle")
               (:organism "Specialized organs, event-bus"))
    :default :squad
    :inferred-from '(:goal-keywords "review" :project-files "AGENTS.md"))

   (:id :model-tier
    :prompt "Model tier for this run?"
    :options '((:local-only "Local only, zero cost (Qwen-AgentWorld-35B)")
               (:budget-50 "Up to 50¢ remote (deepseek-v4-flash-0731)")
               (:budget-200 "Up to $2 remote (glm-5.2 / deepseek-v4-flash-0731)")
               (:unlimited "No budget cap"))
    :default :budget-50
    :inferred-from '(:system-context "unsloth-studio active" :optmem "cost routing v2 active"))

   (:id :continue-policy
    :prompt "Autonomous continuation?"
    :options '((:manual "Stop after first deliverable; human gates each phase")
               (:token-aware "Continue while token budget < 80%; pause at 90%")
               (:full-auto "Run to completion; report only blockers"))
    :default :manual
    :inferred-from '(:goal-scope "multi-project" :squad-type :squad))

   (:id :journal-detail
    :prompt "Journal verbosity?"
    :options '((:minimal "Projected + actual paths only")
               (:standard "Projected + actual + per-member timeline (default)")
               (:verbose "Full token accounting, diffs, decision rationale"))
    :default :standard)

   (:id :strategy-name
    :prompt "Save this configuration as a named strategy?"
    :type :optional-text
    :placeholder "e.g. agile-review, nightly-audit, feature-sprint"
    :inferred-from '(:goal-pattern "review.*AGENTS")))
```

### Inference Rules (examples)

| Context Signal | Inferred Default |
|----------------|------------------|
| Goal contains "review", "audit", "check" | Squad type: `:squad`, Model tier: `:budget-50` |
| Goal contains "implement", "build", "create" | Squad type: `:hierarchy`, Model tier: `:budget-200` |
| Goal contains "design", "architecture", "decide" | Squad type: `:democratic`, Model tier: `:budget-200` |
| Goal contains "monitor", "watch", "daemon" | Squad type: `:organism`, Model tier: `:local-only` |
| `AGENTS.md` present in cwd | Coordinator gets `coordinator-base` template |
| Multiple subdirs with `AGENTS.md` | Scope: `:multi-project`, add `:scout` role |
| `unsloth-studio` systemd active | Local models available → prefer local |
| `llm-budget` shows > $5 remaining | Allow `:budget-200` default |
| Previous squad `duo-review` succeeded | Offer to reuse `:strategy-name "duo-review"` |

---

## 4. From Questionnaire → Squad Spec (Derivation)

The questionnaire answers map to a squad spec programmatically:

```lisp
(defun questionnaire->spec (answers goal)
  (let* ((squad-type (getf answers :squad-type))
         (model-tier (getf answers :model-tier))
         (continue-policy (getf answers :continue-policy))
         (journal-detail (getf answers :journal-detail))
         (strategy-name (getf answers :strategy-name))
         
         ;; Model mapping
         (models (case model-tier
                   (:local-only '((:cli "hermes" :model "unsloth/gemma-4-12b-it-qat-GGUF")
                                  (:cli "opencode" :model "unsloth-local/unsloth/gemma-4-12b-it-qat-GGUF")))
                   (:budget-50 '((:cli "hermes" :model "kimi-k2.6" :provider "kimi-coding")
                                 (:cli "opencode" :model "deepseek/deepseek-v4-flash" :provider "openrouter")))
                   (:budget-200 '((:cli "hermes" :model "kimi-k3" :provider "kimi-coding")
                                  (:cli "opencode" :model "gpt-5.6-luna" :provider "github-copilot")))
                   (:unlimited '((:cli "hermes" :model "kimi-k3" :provider "kimi-coding")
                                 (:cli "opencode" :model "kimi-k3" :provider "kimi-coding")))))
         
         ;; Role layout mapping
         (roles (case squad-type
                  (:squad `((:role "coordinator" ,@(first models)
                             :wake-template "coordinator-base"
                             :cwd ,(project-root))
                            (:role "worker" ,@(second models)
                             :wake-template "worker-base"
                             :cwd ,(project-root))
                            (:role "reviewer" ,@(first models)
                             :wake-template "reviewer-base"
                             :cwd ,(project-root))))
                  (:hierarchy `((:role "lead" ,@(first models)
                                :wake-template "coordinator-base"
                                :cwd ,(project-root))
                               (:role "dev" ,@(second models)
                                :wake-template "worker-base"
                                :cwd ,(project-root))))
                  (:democratic `((:role "peer-1" ,@(first models)
                                 :wake-template "coordinator-base"
                                 :cwd ,(project-root))
                                (:role "peer-2" ,@(second models)
                                 :wake-template "coordinator-base"
                                 :cwd ,(project-root))))
                  (:organism `((:role "queue" ,@(first models)
                                :wake-template "coordinator-base"
                                :cwd ,(project-root))
                               (:role "planner" ,@(second models)
                                :wake-template "worker-base"
                                :cwd ,(project-root))
                               (:role "detox" ,@(first models)
                                :wake-template "reviewer-base"
                                :cwd ,(project-root)))))))
    
    ;; Build spec
    `(squad
      :name ,(generate-squad-name goal strategy-name)
      :version 1
      :description ,goal
      :layout ,(case squad-type (:squad :vertical) (:hierarchy :tiled) (:democratic :horizontal) (:organism :vertical))
      :preflight ,(build-preflight model-tier continue-policy)
      :members ,roles
      :journal ,(build-journal-config journal-detail strategy-name))))
```

---

## 5. Autonomous Continuation (Token-Aware)

When `--continue-policy :token-aware` or `:full-auto`:

### Token Budget Management

```lisp
(defparameter *continuation-thresholds*
  '((:pause-at-pct 90)       ; Pause and ask when 90% of budget used
    (:warn-at-pct 75)        ; Log warning at 75%
    (:checkpoint-interval 5) ; Checkpoint every 5 turns
    (:max-continuation-turns 50))) ; Hard cap
```

### Continuation Protocol

1. **After each phase** (deliverable written, test passes, decision recorded):
   - Check `llm-budget --remaining-cents`
   - Check token usage from model-runtime
   - If `remaining < threshold` → persist state, write continuation prompt, pause
   - If `turns > max` → persist state, write continuation prompt, pause

2. **Continuation prompt** written to `~/.hngh/squads/<name>-forward.md` (existing mission-control mechanism)
3. **Resume** via `hngh up --continue <squad-name>` or `squad-forward-prompt`

### Background Squads (Daemon Mode)

```bash
hngh up --background --strategy nightly-audit "Run full codebase audit"
```

- Launches via mission-control daemon (M7 wire protocol)
- No tmux — runs in daemon's managed subprocesses
- Journals still written to `~/.hngh/journal/squads/`
- Progress events on internal event bus (`squad.progress`, `squad.checkpoint`, `squad.completed`)
- `hngh-client watch --topic squad.*` to monitor

---

## 6. Squad Strategy Sharing

### Strategy Format (`~/.hngh/squad-strategies/<name>.lisp`)

```lisp
(strategy
  :name "duo-review"
  :version 1
  :description "Two-agent code review: coordinator + reviewer"
  :tags ("review" "code" "duo" "local-first")
  :author "boundring"
  :created-at 20260802
  :defaults
  ((:squad-type :squad)
   (:model-tier :budget-50)
   (:continue-policy :manual)
   (:journal-detail :standard))
  :template-overrides
  ((:coordinator "coordinator-review-duo")
   (:reviewer "reviewer-agents-md"))
  :preflight-overrides
  ((:require-systemd :units ("unsloth-studio"))
   (quota-gate :max-remote-cents 50))
  :goal-patterns
  ("review.*AGENTS" "code review" "review.*PR" "audit.*config"))
```

### Strategy Discovery

```bash
# List all strategies
hngh up --list-strategies

# Output:
# Built-in:
#   duo-review        Two-agent code review (coordinator + reviewer)
#   feature-sprint    Hierarchy: lead + 2 devs for implementation
#   design-fork       Democratic: 3 peers for architecture decisions
#   nightly-audit     Organism: queue + planner + detox for overnight runs
#
# User (~/.hngh/squad-strategies/):
#   agile-review      PR review with test generation
#   doc-sync          Keep docs in sync with code changes
#
# Shared (from network, M3):
#   team-code-review  Org-wide review pattern
```

### Sharing Strategies

```bash
# Save current run as strategy
hngh up --save-strategy my-review --from-squad squad-duo-review-20260802T142741Z

# Export for sharing (sanitized — no paths, no secrets)
hngh up --export-strategy my-review > my-review.strategy.lisp

# Import shared strategy
hngh up --import-strategy ./shared-strategy.lisp
```

**Sanitization rules** (for social sharing):
- Strip absolute paths → use `{{project-root}}`, `{{hngh-home}}`
- Strip model API keys, endpoints → use model names only
- Strip user-specific IDs → use role names only
- Keep: role layouts, model tiers, templates, preflight gates, journal config

---

## 7. Integration Points

### With Existing Systems

| System | Integration |
|--------|-------------|
| `mission-control.lisp` | `squad-up`, `squad-forward-prompt`, `squad-status` |
| `squad` launcher | Reused for attended tmux path |
| `agent-call` | For headless member invocation (background squads) |
| `llm-budget` | Budget gates, continuation thresholds |
| `model-runtime` | Model health, benchmark data for model-tier defaults |
| `OptMem` | Questionnaire context, shared memory contract |
| `ai-orchestrator` | Task-driver for background squad phases |
| `hnghbeats` | Squad events condensed into daily beats |
| `knowledge-base` | Lessons learned from actual journals |

### New Mission-Control Functions Needed

```lisp
(defun hngh-up-derive-spec (goal &key interactive strategy-name overrides)
  "Run questionnaire (if interactive), merge with strategy/overrides, return spec.")

(defun hngh-up-launch (spec &key background continue-from)
  "Launch squad from derived spec. Returns squad state.")

(defun hngh-up-continue (squad-name &key policy)
  "Resume squad with continuation policy.")

(defun hngh-up-list-strategies ()
  "Return merged list of built-in + user + shared strategies.")

(defun hngh-up-save-strategy (name squad-state &key sanitize)
  "Persist squad configuration as reusable strategy.")
```

---

## 8. Implementation Phases

### Phase 1: Core CLI + Questionnaire (M1.15)
- [ ] Add `up` subcommand to `hngh-client` (`src/client/main.lisp`)
- [ ] Implement questionnaire generation in Lisp (`src/plugins/hngh-up.lisp` new)
- [ ] Questionnaire rendering in terminal (TUI or simple readline)
- [ ] Spec derivation from answers
- [ ] Integration with `squad-up` (mission-control)

### Phase 2: Strategy System (M2)
- [ ] Strategy file format + persistence
- [ ] `--list-strategies`, `--save-strategy`, `--import/export`
- [ ] Built-in strategies (duo-review, feature-sprint, design-fork, nightly-audit)
- [ ] Sanitization for sharing

### Phase 3: Autonomous Continuation (M2+)
- [ ] Token-aware continuation in mission-control
- [ ] Background squad launch via daemon (M7 wire protocol)
- [ ] Event bus topics for squad progress
- [ ] `hngh up --continue` and `hngh-client watch --topic squad.*`

### Phase 4: Social Sharing (M3)
- [ ] Network strategy registry (peer-to-peer)
- [ ] Strategy ratings/comments
- [ ] Auto-suggest strategies from network for goal patterns

---

## 9. UX Consistency

| Command | Pattern | Example |
|---------|---------|---------|
| `squad up` | Low-level, spec-file required | `squad up squads/duo-review.spec` |
| `squad validate` | Spec validation | `squad validate squads/duo-review.spec` |
| `squad attach` | Attend existing | `squad attach duo-review` |
| `hngh up` | **High-level, goal-driven** | `hngh up "Review AGENTS.md"` |
| `hngh up --dry-run` | Preview without launch | `hngh up --dry-run "Add tests"` |
| `hngh up --continue` | Resume squad | `hngh up --continue squad-duo-review` |

---

## 10. Example Run

```bash
$ hngh up "Review all AGENTS.md files in ~/Projects/etc and propose unified conventions"

╭────────────────────────────────────────────────────────────────────╮
│ hngh-up — Squad Spin-Up                                            │
│ Goal: Review all AGENTS.md files in ~/Projects/etc...              │
├────────────────────────────────────────────────────────────────────┤
│ Detected context:                                                  │
│   • Project: hngh (Common Lisp, SBCL, AGENTS.md present)           │
│   • 3 subdirs with AGENTS.md: ./, ./sysconfig_mgmt/, ./hngh/       │
│   • Local models: unsloth-studio active (gemma-4-12b @ :8888)      │
│   • Budget: $3.47 remaining today (llm-budget)                     │
│   • Last similar run: duo-review 2026-08-02 (success)              │
├────────────────────────────────────────────────────────────────────┤
│ Questionnaire (3 questions — press Enter for defaults):            │
│                                                                    │
│ 1. Squad layout? [squad]                                           │
│    ▸ squad       Fireteam: coordinator + worker + reviewer         │
│      hierarchy   PM → devs, top-down                               │
│      democratic  Consensus circle                                  │
│      organism    Specialized organs, event-bus                     │
│                                                                    │
│ 2. Model tier? [budget-50]                                         │
│    ▸ budget-50   Up to 50¢ remote (kimi-k2.6 / deepseek-v4-flash) │
│      local-only  Zero cost (gemma-4-12b only)                      │
│      budget-200  Up to $2 remote (kimi-k3 / gpt-5.6-luna)         │
│      unlimited   No budget cap                                     │
│                                                                    │
│ 3. Save as named strategy? [duo-review]                            │
│    (empty = don't save)                                            │
│                                                                    │
├────────────────────────────────────────────────────────────────────┤
│ Derived spec preview:                                              │
│   Squad: squad-duo-review-20260802T143022Z                         │
│   Layout: vertical (3 panes)                                       │
│   Members: coordinator(opencode/kimi-k2.6), worker(hermes/gemma), │
│            reviewer(opencode/deepseek-v4-flash)                    │
│   Preflight: unsloth-studio, gemma-4-12b healthy, quota 50¢       │
│   Journal: standard detail, projected + actual                     │
│                                                                    │
│ Launch? [Y/n]                                                      │
╰────────────────────────────────────────────────────────────────────╯
```

---

## 11. Acceptance Criteria

1. **`hngh up "goal"`** — Runs questionnaire, shows derived spec, launches squad on confirm
2. **`hngh up --dry-run "goal"`** — Shows questionnaire + derived spec, exits without launch
3. **`hngh up --strategy duo-review "goal"`** — Skips questionnaire, uses strategy defaults
4. **`hngh up --list-strategies`** — Lists built-in + user strategies with descriptions
5. **`hngh up --save-strategy my-review`** — Persists sanitized strategy to `~/.hngh/squad-strategies/`
6. **Questionnaire ≤ 5 questions** — Adaptive, context-aware, sensible defaults
7. **Spec derivation deterministic** — Same answers → same spec (modulo timestamps)
8. **Integration with mission-control** — Uses existing `squad-up`, `squad-forward-prompt`, state
9. **Token-aware continuation** — Pauses at thresholds, writes forward prompt, resumable
10. **Strategies shareable** — Export/import sanitized, no secrets/paths leak

---

## 12. References

- Squad specs: `data/squads.lisp`, `squads/*.spec`
- Launcher: `~/.local/bin/squad`
- Mission control: `src/plugins/mission-control.lisp`
- Templates: `squads/templates/*.md`
- Platoons design: `docs/design/agent-platoons.md`
- Night squad config: `~/.hngh-night/squad-seats.conf`
- OptMem: `~/.optmem/memo`
- Model routing: `docs/design/model-routing.md`