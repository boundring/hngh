# Prompt Matrix — Skeleton-Bones-Flesh Plugin Spec (Wave 5)

**Status**: Draft v0.1 (2026-08-03)
**Design session**: D5
**Milestone**: M9 Wave 5 (extends Wave 1 generate-pm-prompt, Wave 4 beans)
**Author**: Designer — glm-5.2, Hermes harness
**Depends on**: `docs/design/squad-startup-automation.md` §5, `docs/design/model-pareto.md` §3, `docs/design/beans-aesthetic.md`, `docs/design/projected-design-sessions.md` D5

---

## 1. Overview

The prompt matrix extends the existing `generate-pm-prompt` (Wave 1, C7) into
`generate-prompt`, a full dimensional prompt generator. Every role in every
scenario gets a prompt assembled from a three-stage pipeline:

1. **Skeleton** — a static markdown template with labeled slots, selected by
   dimension values. No context, no LLM. Pure structure.
2. **Bones** — procedurally filled slots. AGENTS.md sections, plan summaries,
   system context, roadmap status, OptMem notes, model assignment. All
   deterministic: filesystem reads, string lookups, no inference.
3. **Flesh** — optional LLM once-over. The cheapest available non-local model
   reads the assembled skeleton+bones and edits for coherence. Only step
   that costs tokens. Skipped when bones are deterministic-identical to a
   cached prompt, when the assigned model is local, or when budget is zero.

The existing `generate-pm-prompt` is preserved as a backward-compatible entry
point that calls `generate-prompt` with `:role :pm :scenario :startup`.

**Files touched**:
- `src/plugins/hngh-up.lisp` (extend — add generate-prompt, select-role-model,
  skeleton library, bone fillers, flesh pass, prompt cache)
- `src/packages.lisp` (extend `:hngh.plugins.hngh-up` export list)
- `tests/unit/test-hngh-up.lisp` (extend — prompt matrix test fixtures)

---

## 2. Dimension Table

Prompts are assembled from a matrix of categorical dimensions. The generator
selects values per dimension based on context, then fills the template.

| Dimension | Type | Values | Selected by |
|---|---|---|---|
| `role` | keyword | `:pm`, `:designer`, `:coder`, `:artist`, `:accountant`, `:worker` | dispatch target |
| `scenario` | keyword | `:startup`, `:task-assign`, `:status-check`, `:review`, `:shutdown`, `:unblock` | squad event |
| `strategy` | keyword | `:duo-review`, `:feature-sprint`, `:design-fork`, `:nightly-audit` | squad type or saved strategy |
| `resources` | keyword | `:local-only`, `:budget-50`, `:budget-200`, `:unlimited` | model tier + VRAM gate |
| `squad-count` | integer | 1, 2, 3, 6, N (fanout) | role layout |
| `roles-active` | list | subset of all roles | current dispatch tree state |
| `lifetime` | keyword | `:ephemeral`, `:continual`, `:purpose-bounded` | squad intent |
| `directory` | plist | `:cwd`, `:agents-md-sections`, `:plans`, `:designs` | working directory context |
| `system` | plist | `:gpu-count`, `:vram-total-mb`, `:vram-free-mb`, `:local-models`, `:systemd-units` | resource-manager + model-runtime |
| `purpose` | string | goal string | user input or planner decomposition |

### Dimension representation

```lisp
(defstruct prompt-dimensions
  role          ; keyword: :pm | :designer | :coder | :artist | :accountant | :worker
  scenario      ; keyword: :startup | :task-assign | :status-check | :review | :shutdown | :unblock
  strategy      ; keyword: :duo-review | :feature-sprint | :design-fork | :nightly-audit
  resources     ; keyword: :local-only | :budget-50 | :budget-200 | :unlimited
  squad-count   ; integer
  roles-active  ; list of keywords
  lifetime      ; keyword: :ephemeral | :continual | :purpose-bounded
  directory     ; plist: (:cwd path :agents-md sections :plans list :designs list)
  system        ; plist: (:gpu-count n :vram-total-mb n :vram-free-mb n :local-models list :systemd-units list)
  purpose)      ; string: the goal
```

### Dimension selection procedures

Each dimension has a deterministic selection function. No LLM.

| Dimension | Selection function | Logic |
|---|---|---|
| `role` | `select-role` | From dispatch target — the role the PM is dispatching to. Direct argument. |
| `scenario` | `select-scenario` | From squad event type. `:startup` at squad creation, `:task-assign` on dispatch, `:status-check` on periodic review, `:review` on artifact completion, `:shutdown` on pause/stop, `:unblock` on blocker detection. |
| `strategy` | `select-strategy` | From saved strategy name or derived from squad-type answer in questionnaire. Maps `:squad`→`:duo-review`, `:hierarchy`→`:feature-sprint`, `:democratic`→`:design-fork`, `:organism`→`:nightly-audit`. |
| `resources` | `select-resources` | From model-tier questionnaire answer. `:local-only`, `:budget-50`, `:budget-200`, `:unlimited`. |
| `squad-count` | `select-squad-count` | Length of `roles-active` list. |
| `roles-active` | `select-roles-active` | Read dispatch tree `dispatch.md` roles table, filter by `active` status. Falls back to full role set for the strategy layout. |
| `lifetime` | `select-lifetime` | From questionnaire continue-policy or explicit argument. `:manual`→`:ephemeral`, `:token-aware`→`:continual`, `:full-auto`→`:purpose-bounded`. |
| `directory` | `select-directory` | Filesystem scan: `discover-agents-md` for sections, `%scan-plans` for plans, `%scan-design-docs` for designs, `uiop:getcwd` for `:cwd`. |
| `system` | `select-system` | `%gather-system-context` (existing function) + systemd unit list from `(uiop:run-program '("systemctl" "--user" "list-units" "--type=service" "--state=running" "--no-legend") :output :string)`. |
| `purpose` | `select-purpose` | Direct — the goal string from user input or planner decomposition. |

---

## 3. Skeleton Template Library

36 base skeletons: 6 roles × 6 scenarios. Each skeleton is a markdown template
with labeled slots using the `{{slot-name}}` convention.

### 3.1 Slot taxonomy

Every skeleton uses some subset of these labeled slots:

| Slot | Filled by | Deterministic? | Source |
|---|---|---|---|
| `{{role}}` | role name | yes | dimension value |
| `{{squad-name}}` | squad name | yes | squad spec |
| `{{model}}` | assigned model name | yes | select-role-model result |
| `{{provider}}` | model provider | yes | model table |
| `{{cwd}}` | working directory | yes | directory dimension |
| `{{agents-md-sections}}` | AGENTS.md section list | yes | agents-md merge |
| `{{agents-md-key-facts}}` | AGENTS.md facts | yes | agents-md merge |
| `{{plans}}` | plan summaries | yes | `%scan-plans` |
| `{{design-docs}}` | design doc list | yes | `%scan-design-docs` |
| `{{roadmap-status}}` | roadmap status line | yes | `%read-roadmap-status` |
| `{{system-context}}` | GPU/VRAM/local models | yes | `%gather-system-context` |
| `{{optmem-notes}}` | OptMem wake output | yes | `%run-optmem-wake` |
| `{{goal}}` | purpose string | yes | dimension value |
| `{{lifetime-policy}}` | lifetime description | yes | `%format-lifetime-policy` |
| `{{task-id}}` | task identifier | yes | dispatch tree task |
| `{{task-title}}` | task title | yes | dispatch tree task |
| `{{task-files}}` | files to touch | yes | task spec |
| `{{task-acceptance}}` | acceptance criteria | yes | task spec |
| `{{task-preconditions}}` | precondition gates | yes | task spec |
| `{{task-attribution}}` | attribution line | yes | role + model + harness |
| `{{bean-vocabulary}}` | bean vernacular for role | yes | bean-aesthetic role table |
| `{{model-recommendations}}` | model assignment table | yes | select-role-model per-role |
| `{{coordination-protocol}}` | coordination instructions | yes | AGENTS.md coordination section |
| `{{build-test-commands}}` | make build / make test | yes | AGENTS.md repo notes |
| `{{review-criteria}}` | review criteria | yes | task spec |
| `{{severity-levels}}` | severity scale | yes | static string |
| `{{verdict-format}}` | verdict template | yes | static string |
| `{{blocker-description}}` | blocker text | yes | role status report |
| `{{available-resources}}` | resource snapshot | yes | system + budget |
| `{{suggested-paths}}` | unblock suggestions | yes | static per scenario |
| `{{fragment-journal}}` | journal fragment path | yes | squad journal |
| `{{resume-hint}}` | resume instruction | yes | fragment journal |
| `{{value-captured}}` | work summary | yes | fragment journal |
| `{{aesthetic-brief}}` | aesthetic direction | yes | beans-aesthetic role table |
| `{{visual-references}}` | visual references | yes | design doc |
| `{{constraints}}` | task constraints | yes | task spec |
| `{{cost-audit-request}}` | audit scope | yes | accountant task spec |
| `{{resource-snapshot}}` | budget summary | yes | system + budget |
| `{{budget}}` | budget remaining | yes | budget gate |
| `{{task-batch}}` | batch task list | yes | worker task spec |

### 3.2 Skeleton definitions

Each skeleton is a function returning a string template with `{{slot}}`
placeholders. Skeletons are indexed by `(role . scenario)` in a hash table.

```lisp
(defparameter *skeleton-library* (make-hash-table :test 'equal)
  "Key: (role . scenario) cons. Value: template string with {{slot}} markers.")

(defun skeleton-key (role scenario)
  (cons role scenario))

(defun get-skeleton (role scenario)
  "Return the template string for ROLE×SCENARIO, or NIL if undefined."
  (gethash (skeleton-key role scenario) *skeleton-library*))
```

### 3.3 All 36 skeletons

#### STARTUP skeletons (6)

**STARTUP-PM** — `(:pm . :startup)`

```
# {{role}} First Prompt — Squad: {{squad-name}}

## 1. Orientation

Look around. Read AGENTS.md, check OptMem, check tasks. You are the PM.
Your job: orient, decompose, dispatch, monitor, review.

## 2. Context Summary

### Repo
Working directory: {{cwd}}

### AGENTS.md Sections
{{agents-md-sections}}

### Key Facts
{{agents-md-key-facts}}

### Plans (.hermes/plans/)
{{plans}}

### Design Docs (docs/design/)
{{design-docs}}

### System Context
{{system-context}}

## 3. Roadmap State
{{roadmap-status}}

## 4. OptMem Notes
{{optmem-notes}}

## 5. Intent
Goal: {{goal}}

This squad exists to accomplish the above goal. Understand the context,
decompose the work, and coordinate the squad to deliver.

## 6. Lifetime Policy
{{lifetime-policy}}

## 7. Model Recommendations
{{model-recommendations}}

## 8. Coordination Protocol
{{coordination-protocol}}

## 9. Bean Vocabulary
{{bean-vocabulary}}
```

**STARTUP-DESIGNER** — `(:designer . :startup)`

```
# {{role}} — Squad: {{squad-name}}

## 1. Orientation
You are the Designer. Read AGENTS.md, understand the squad goal, check
your inbox for task beans. Your role: decompose goals into specs, design
systems, write design docs.

## 2. Scope
Working directory: {{cwd}}
Squad goal: {{goal}}

## 3. Design Request
{{task-title}}

## 4. Context
### AGENTS.md Sections
{{agents-md-sections}}

### Key Facts
{{agents-md-key-facts}}

### Plans
{{plans}}

### Design Docs
{{design-docs}}

### Roadmap
{{roadmap-status}}

### System
{{system-context}}

## 5. Dependencies
{{task-preconditions}}

## 6. Aesthetic Direction
{{aesthetic-brief}}

## 7. Bean Vocabulary
{{bean-vocabulary}}

## 8. Model Assignment
{{model-recommendations}}

## 9. Build & Test
{{build-test-commands}}

## 10. Attribution
{{task-attribution}}
```

**STARTUP-CODER** — `(:coder . :startup)`

```
# {{role}} — Squad: {{squad-name}}

## 1. Orientation
You are the Coder. Read AGENTS.md, check your inbox for task beans, run
`make build && make test` to verify the baseline. Your role: implement
from specs, write tests, keep make test green.

## 2. Scope
Working directory: {{cwd}}
Squad goal: {{goal}}

## 3. Task Spec
{{task-title}}

## 4. Preconditions
{{task-preconditions}}

## 5. Files
{{task-files}}

## 6. Context
### AGENTS.md Sections
{{agents-md-sections}}

### Key Facts
{{agents-md-key-facts}}

### Plans
{{plans}}

### Roadmap
{{roadmap-status}}

### System
{{system-context}}

## 7. Conventions
{{build-test-commands}}
{{coordination-protocol}}

## 8. Bean Vocabulary
{{bean-vocabulary}}

## 9. Model Assignment
{{model-recommendations}}

## 10. Attribution
{{task-attribution}}
```

**STARTUP-ARTIST** — `(:artist . :startup)`

```
# {{role}} — Squad: {{squad-name}}

## 1. Orientation
You are the Artist. Read AGENTS.md, check your inbox for design beans.
Your role: transmute design concepts into visual artifacts — ASCII art,
diagrams, aesthetic assets.

## 2. Scope
Working directory: {{cwd}}
Squad goal: {{goal}}

## 3. Aesthetic Brief
{{aesthetic-brief}}

## 4. Visual References
{{visual-references}}

## 5. Context
### AGENTS.md Sections
{{agents-md-sections}}

### Design Docs
{{design-docs}}

### Roadmap
{{roadmap-status}}

### System
{{system-context}}

## 6. Constraints
{{constraints}}

## 7. Bean Vocabulary
{{bean-vocabulary}}

## 8. Model Assignment
{{model-recommendations}}

## 9. Attribution
{{task-attribution}}
```

**STARTUP-ACCOUNTANT** — `(:accountant . :startup)`

```
# {{role}} — Squad: {{squad-name}}

## 1. Orientation
You are the Accountant. Read AGENTS.md, check your inbox for audit
requests. Your role: track costs, audit husks, monitor squad health,
detect spoilage and feral outbreaks.

## 2. Scope
Working directory: {{cwd}}
Squad goal: {{goal}}

## 3. Cost Audit Request
{{cost-audit-request}}

## 4. Resource Snapshot
### System
{{system-context}}

### Budget
{{budget}}

## 5. Context
### AGENTS.md Sections
{{agents-md-sections}}

### Roadmap
{{roadmap-status}}

## 6. Bean Vocabulary
{{bean-vocabulary}}

## 7. Model Assignment
{{model-recommendations}}

## 8. Attribution
{{task-attribution}}
```

**STARTUP-WORKER** — `(:worker . :startup)`

```
# {{role}} — Squad: {{squad-name}}

## 1. Orientation
You are the Worker. Read AGENTS.md, check your inbox for task beans.
Your role: forage batch tasks, digest them, produce status beans.

## 2. Scope
Working directory: {{cwd}}
Squad goal: {{goal}}

## 3. Task Batch
{{task-batch}}

## 4. Preconditions
{{task-preconditions}}

## 5. Context
### AGENTS.md Sections
{{agents-md-sections}}

### Key Facts
{{agents-md-key-facts}}

### Roadmap
{{roadmap-status}}

## 6. Conventions
{{build-test-commands}}
{{coordination-protocol}}

## 7. Bean Vocabulary
{{bean-vocabulary}}

## 8. Model Assignment
{{model-recommendations}}

## 9. Attribution
{{task-attribution}}
```

#### TASK-ASSIGN skeletons (6)

**TASK-ASSIGN-PM** — `(:pm . :task-assign)`

```
# {{role}} Task Dispatch — Squad: {{squad-name}}

## Task
ID: {{task-id}}
Title: {{task-title}}
Assigned to: {{role}}
Files: {{task-files}}

## Acceptance Criteria
{{task-acceptance}}

## Preconditions
{{task-preconditions}}

## Context
{{agents-md-sections}}
{{roadmap-status}}
{{optmem-notes}}

## Attribution
{{task-attribution}}
```

**TASK-ASSIGN-DESIGNER** — `(:designer . :task-assign)`

```
# {{role}} Task — Squad: {{squad-name}}

## Task
ID: {{task-id}}
Title: {{task-title}}

## Files
{{task-files}}

## Acceptance Criteria
{{task-acceptance}}

## Preconditions
{{task-preconditions}}

## Context
Working directory: {{cwd}}
{{agents-md-sections}}
{{design-docs}}
{{roadmap-status}}

## Model Assignment
{{model-recommendations}}

## Attribution
{{task-attribution}}
```

**TASK-ASSIGN-CODER** — `(:coder . :task-assign)`

```
# {{role}} Task — Squad: {{squad-name}}

## Task
ID: {{task-id}}
Title: {{task-title}}

## Files
{{task-files}}

## Acceptance Criteria
{{task-acceptance}}

## Preconditions
{{task-preconditions}}

## Context
Working directory: {{cwd}}
{{agents-md-key-facts}}
{{build-test-commands}}
{{coordination-protocol}}

## Model Assignment
{{model-recommendations}}

## Attribution
{{task-attribution}}
```

**TASK-ASSIGN-ARTIST** — `(:artist . :task-assign)`

```
# {{role}} Task — Squad: {{squad-name}}

## Task
ID: {{task-id}}
Title: {{task-title}}

## Aesthetic Brief
{{aesthetic-brief}}

## Visual References
{{visual-references}}

## Acceptance Criteria
{{task-acceptance}}

## Constraints
{{constraints}}

## Context
Working directory: {{cwd}}
{{design-docs}}

## Model Assignment
{{model-recommendations}}

## Attribution
{{task-attribution}}
```

**TASK-ASSIGN-ACCOUNTANT** — `(:accountant . :task-assign)`

```
# {{role}} Task — Squad: {{squad-name}}

## Task
ID: {{task-id}}
Title: {{task-title}}

## Cost Audit Scope
{{cost-audit-request}}

## Resource Snapshot
{{resource-snapshot}}
{{budget}}

## Acceptance Criteria
{{task-acceptance}}

## Context
Working directory: {{cwd}}
{{agents-md-sections}}

## Model Assignment
{{model-recommendations}}

## Attribution
{{task-attribution}}
```

**TASK-ASSIGN-WORKER** — `(:worker . :task-assign)`

```
# {{role}} Task — Squad: {{squad-name}}

## Task Batch
ID: {{task-id}}
{{task-batch}}

## Preconditions
{{task-preconditions}}

## Acceptance Criteria
{{task-acceptance}}

## Context
Working directory: {{cwd}}
{{agents-md-key-facts}}
{{build-test-commands}}

## Model Assignment
{{model-recommendations}}

## Attribution
{{task-attribution}}
```

#### STATUS-CHECK skeletons (6)

**STATUS-CHECK-PM** — `(:pm . :status-check)`

```
# {{role}} Status Check — Squad: {{squad-name}}

## Roles
{{roles-active}}

## System
{{system-context}}
{{budget}}

## OptMem
{{optmem-notes}}

## Roadmap
{{roadmap-status}}

## Action Required
Review dispatch tree, check for stale beans, re-dispatch or adjust.
```

**STATUS-CHECK-DESIGNER** — `(:designer . :status-check)`

```
# {{role}} Status Check — Squad: {{squad-name}}

## Current Task
{{task-title}}

## Progress
Report your current state: digesting, fallow, or blocked.

## Context
{{cwd}}
{{design-docs}}
{{roadmap-status}}
```

**STATUS-CHECK-CODER** — `(:coder . :status-check)`

```
# {{role}} Status Check — Squad: {{squad-name}}

## Current Task
{{task-title}}

## Progress
Run `make test`. Report: green/red, what changed, what's next.

## Context
{{cwd}}
{{build-test-commands}}
```

**STATUS-CHECK-ARTIST** — `(:artist . :status-check)`

```
# {{role}} Status Check — Squad: {{squad-name}}

## Current Task
{{task-title}}

## Progress
Report: transmuting, rendering, or fallow.

## Context
{{design-docs}}
```

**STATUS-CHECK-ACCOUNTANT** — `(:accountant . :status-check)`

```
# {{role}} Status Check — Squad: {{squad-name}}

## Audit Status
Report: husk pile depth, spoilage detected, budget consumed.

## Resource Snapshot
{{resource-snapshot}}
{{budget}}
```

**STATUS-CHECK-WORKER** — `(:worker . :status-check)`

```
# {{role}} Status Check — Squad: {{squad-name}}

## Current Task
{{task-title}}

## Progress
Report: foraging, digesting, or fallow.

## Context
{{cwd}}
```

#### REVIEW skeletons (6)

**REVIEW-PM** — `(:pm . :review)`

```
# {{role}} Review — Squad: {{squad-name}}

## Artifact
{{task-files}}

## Review Criteria
{{review-criteria}}

## Severity Levels
{{severity-levels}}

## Verdict Format
{{verdict-format}}

## Context
{{roadmap-status}}
{{optmem-notes}}
```

**REVIEW-DESIGNER** — `(:designer . :review)`

```
# {{role}} Design Review — Squad: {{squad-name}}

## Artifact
{{task-files}}

## Review Criteria
{{review-criteria}}

## Severity Levels
{{severity-levels}}

## Context
{{design-docs}}
{{roadmap-status}}
```

**REVIEW-CODER** — `(:coder . :review)`

```
# {{role}} Code Review — Squad: {{squad-name}}

## Artifact
{{task-files}}

## Review Criteria
{{review-criteria}}

## Severity Levels
{{severity-levels}}

## Context
{{cwd}}
{{build-test-commands}}
```

**REVIEW-ARTIST** — `(:artist . :review)`

```
# {{role}} Art Review — Squad: {{squad-name}}

## Artifact
{{task-files}}

## Review Criteria
{{review-criteria}}

## Aesthetic Standards
{{aesthetic-brief}}

## Context
{{design-docs}}
```

**REVIEW-ACCOUNTANT** — `(:accountant . :review)`

```
# {{role}} Audit Review — Squad: {{squad-name}}

## Artifact
{{task-files}}

## Review Criteria
{{review-criteria}}

## Cost Audit
{{cost-audit-request}}
{{budget}}
```

**REVIEW-WORKER** — `(:worker . :review)`

```
# {{role}} Output Review — Squad: {{squad-name}}

## Artifact
{{task-files}}

## Review Criteria
{{review-criteria}}

## Context
{{cwd}}
```

#### SHUTDOWN skeletons (6)

**SHUTDOWN-PM** — `(:pm . :shutdown)`

```
# {{role}} Shutdown — Squad: {{squad-name}}

## Fragment Journal
{{fragment-journal}}

## Resume Hint
{{resume-hint}}

## Value Captured
{{value-captured}}

## Final Status
Report: squad summary, what was accomplished, what remains.

## Attribution
{{task-attribution}}
```

**SHUTDOWN-DESIGNER** — `(:designer . :shutdown)`

```
# {{role}} Shutdown — Squad: {{squad-name}}

## Fragment Journal
{{fragment-journal}}

## Resume Hint
{{resume-hint}}

## Value Captured
{{value-captured}}

## Context
{{design-docs}}
{{roadmap-status}}

## Attribution
{{task-attribution}}
```

**SHUTDOWN-CODER** — `(:coder . :shutdown)`

```
# {{role}} Shutdown — Squad: {{squad-name}}

## Fragment Journal
{{fragment-journal}}

## Resume Hint
{{resume-hint}}

## Value Captured
{{value-captured}}

## Final State
Run `make test`. Report final status.

## Context
{{cwd}}
{{build-test-commands}}

## Attribution
{{task-attribution}}
```

**SHUTDOWN-ARTIST** — `(:artist . :shutdown)`

```
# {{role}} Shutdown — Squad: {{squad-name}}

## Fragment Journal
{{fragment-journal}}

## Resume Hint
{{resume-hint}}

## Value Captured
{{value-captured}}

## Context
{{design-docs}}

## Attribution
{{task-attribution}}
```

**SHUTDOWN-ACCOUNTANT** — `(:accountant . :shutdown)`

```
# {{role}} Shutdown — Squad: {{squad-name}}

## Fragment Journal
{{fragment-journal}}

## Resume Hint
{{resume-hint}}

## Value Captured
{{value-captured}}

## Final Audit
Report: total cost, husk count, spoilage rate.

## Attribution
{{task-attribution}}
```

**SHUTDOWN-WORKER** — `(:worker . :shutdown)`

```
# {{role}} Shutdown — Squad: {{squad-name}}

## Fragment Journal
{{fragment-journal}}

## Resume Hint
{{resume-hint}}

## Value Captured
{{value-captured}}

## Context
{{cwd}}

## Attribution
{{task-attribution}}
```

#### UNBLOCK skeletons (6)

**UNBLOCK-PM** — `(:pm . :unblock)`

```
# {{role}} Unblock — Squad: {{squad-name}}

## Blocker
{{blocker-description}}

## Available Resources
{{available-resources}}

## Suggested Paths
{{suggested-paths}}

## Context
{{optmem-notes}}
{{roadmap-status}}
```

**UNBLOCK-DESIGNER** — `(:designer . :unblock)`

```
# {{role}} Unblock — Squad: {{squad-name}}

## Blocker
{{blocker-description}}

## Available Resources
{{available-resources}}

## Suggested Paths
{{suggested-paths}}

## Context
{{design-docs}}
{{roadmap-status}}
```

**UNBLOCK-CODER** — `(:coder . :unblock)`

```
# {{role}} Unblock — Squad: {{squad-name}}

## Blocker
{{blocker-description}}

## Available Resources
{{available-resources}}

## Suggested Paths
{{suggested-paths}}

## Context
{{cwd}}
{{build-test-commands}}
```

**UNBLOCK-ARTIST** — `(:artist . :unblock)`

```
# {{role}} Unblock — Squad: {{squad-name}}

## Blocker
{{blocker-description}}

## Available Resources
{{available-resources}}

## Suggested Paths
{{suggested-paths}}

## Context
{{design-docs}}
```

**UNBLOCK-ACCOUNTANT** — `(:accountant . :unblock)`

```
# {{role}} Unblock — Squad: {{squad-name}}

## Blocker
{{blocker-description}}

## Available Resources
{{available-resources}}
{{budget}}

## Suggested Paths
{{suggested-paths}}
```

**UNBLOCK-WORKER** — `(:worker . :unblock)`

```
# {{role}} Unblock — Squad: {{squad-name}}

## Blocker
{{blocker-description}}

## Available Resources
{{available-resources}}

## Suggested Paths
{{suggested-paths}}

## Context
{{cwd}}
```

---

## 4. Bone-Filling Procedures

Bones are the deterministic slot-fillers. Each slot has a filler function that
reads from the filesystem or computes from dimension values. No LLM, no
inference, no generation.

### 4.1 Filler function registry

```lisp
(defparameter *bone-fillers*
  '((:role                . fill-role)
    (:squad-name           . fill-squad-name)
    (:model                . fill-model)
    (:provider             . fill-provider)
    (:cwd                  . fill-cwd)
    (:agents-md-sections   . fill-agents-md-sections)
    (:agents-md-key-facts  . fill-agents-md-key-facts)
    (:plans                . fill-plans)
    (:design-docs          . fill-design-docs)
    (:roadmap-status       . fill-roadmap-status)
    (:system-context       . fill-system-context)
    (:optmem-notes         . fill-optmem-notes)
    (:goal                 . fill-goal)
    (:lifetime-policy      . fill-lifetime-policy)
    (:task-id              . fill-task-id)
    (:task-title           . fill-task-title)
    (:task-files           . fill-task-files)
    (:task-acceptance      . fill-task-acceptance)
    (:task-preconditions   . fill-task-preconditions)
    (:task-attribution     . fill-task-attribution)
    (:bean-vocabulary      . fill-bean-vocabulary)
    (:model-recommendations . fill-model-recommendations)
    (:coordination-protocol . fill-coordination-protocol)
    (:build-test-commands  . fill-build-test-commands)
    (:review-criteria      . fill-review-criteria)
    (:severity-levels      . fill-severity-levels)
    (:verdict-format       . fill-verdict-format)
    (:blocker-description  . fill-blocker-description)
    (:available-resources  . fill-available-resources)
    (:suggested-paths      . fill-suggested-paths)
    (:fragment-journal     . fill-fragment-journal)
    (:resume-hint          . fill-resume-hint)
    (:value-captured       . fill-value-captured)
    (:aesthetic-brief      . fill-aesthetic-brief)
    (:visual-references    . fill-visual-references)
    (:constraints          . fill-constraints)
    (:cost-audit-request   . fill-cost-audit-request)
    (:resource-snapshot    . fill-resource-snapshot)
    (:budget               . fill-budget)
    (:task-batch           . fill-task-batch)
    (:roles-active         . fill-roles-active))
  "Maps slot keyword → filler function symbol.
Each filler takes (DIMENSIONS TASK-SPEC SQUAD-NAME) and returns a string.")
```

### 4.2 Filler function specifications

Each filler function has signature:

```lisp
(defun fill-X (dimensions task-spec squad-name)
  "Fill the {{X}} slot. Returns a string."
  ...)
```

Where `dimensions` is a `prompt-dimensions` struct, `task-spec` is a plist
(from dispatch tree task, may be NIL for startup scenarios), and `squad-name`
is a string.

| Slot | Filler function | Source | Behavior |
|---|---|---|---|
| `{{role}}` | `fill-role` | `prompt-dimensions-role` | Returns the role keyword as a downcase string: `:pm` → `"pm"`. |
| `{{squad-name}}` | `fill-squad-name` | direct argument | Returns `squad-name`. |
| `{{model}}` | `fill-model` | `select-role-model` result | Returns the model name string assigned to this role. Calls `select-role-model` if task-spec has no model. |
| `{{provider}}` | `fill-provider` | model table lookup | Returns the provider string from `*model-pareto-table*` for the assigned model. |
| `{{cwd}}` | `fill-cwd` | `prompt-dimensions-directory` | Returns `(namestring (getf (prompt-dimensions-directory dimensions) :cwd))`. |
| `{{agents-md-sections}}` | `fill-agents-md-sections` | agents-md merge | Calls `discover-agents-md` + `merge-agents-md`, renders section headers as bullet list. Returns `"- (no AGENTS.md found)"` when none. Reuses existing `%section-body-matching` pattern. |
| `{{agents-md-key-facts}}` | `fill-agents-md-key-facts` | agents-md merge | Returns facts from `getf merged :facts` as `"- key: value"` bullets. |
| `{{plans}}` | `fill-plans` | `%scan-plans` | Returns `"- title — first-line"` bullets. Reuses existing `%scan-plans`. |
| `{{design-docs}}` | `fill-design-docs` | `%scan-design-docs` | Returns `"- filename"` bullets. Reuses existing `%scan-design-docs`. |
| `{{roadmap-status}}` | `fill-roadmap-status` | `%read-roadmap-status` | Returns the status string or `"(roadmap.md not found)"`. Reuses existing function. |
| `{{system-context}}` | `fill-system-context` | `%gather-system-context` | Renders GPU count, name, VRAM total/free as formatted string. Reuses existing function. |
| `{{optmem-notes}}` | `fill-optmem-notes` | `%run-optmem-wake` | Returns last 20 lines of OptMem wake output, or `"(no OptMem notes available)"`. Reuses existing function. |
| `{{goal}}` | `fill-goal` | `prompt-dimensions-purpose` | Returns the purpose string. |
| `{{lifetime-policy}}` | `fill-lifetime-policy` | `prompt-dimensions-lifetime` | Calls existing `%format-lifetime-policy`. |
| `{{task-id}}` | `fill-task-id` | `(getf task-spec :id)` | Returns task ID string or `"(no task assigned)"`. |
| `{{task-title}}` | `fill-task-title` | `(getf task-spec :title)` | Returns task title or `"(no task assigned)"`. |
| `{{task-files}}` | `fill-task-files` | `(getf task-spec :files)` | Returns `"- path"` bullets or `"(none specified)"`. |
| `{{task-acceptance}}` | `fill-task-acceptance` | `(getf task-spec :acceptance)` | Returns acceptance criteria or `"(none specified)"`. |
| `{{task-preconditions}}` | `fill-task-preconditions` | `(getf task-spec :preconditions)` | Returns preconditions or `"(none)"`. |
| `{{task-attribution}}` | `fill-task-attribution` | computed | Returns `"<role> — <model>, <harness>"` string. E.g. `"Coder — deepseek-v4-flash, Hermes harness"`. |
| `{{bean-vocabulary}}` | `fill-bean-vocabulary` | static table | Returns the bean vernacular for the role from beans-aesthetic.md. See §4.3. |
| `{{model-recommendations}}` | `fill-model-recommendations` | `select-role-model` per role | Renders the model recommendation table. See §6. |
| `{{coordination-protocol}}` | `fill-coordination-protocol` | AGENTS.md coordination section | Returns the AGENTS.md "Coordination contract" section body, or a default protocol string. |
| `{{build-test-commands}}` | `fill-build-test-commands` | AGENTS.md repo notes | Returns `make build / make test` or the build/test lines from AGENTS.md. Default: `"Build: make build. Test: make test."` |
| `{{review-criteria}}` | `fill-review-criteria` | `(getf task-spec :review-criteria)` | Returns criteria or `"(use standard code review criteria)"`. |
| `{{severity-levels}}` | `fill-severity-levels` | static | Returns: `"blocker — must fix before merge\nmajor — should fix before merge\nminor — can fix later\nnit — optional"`. |
| `{{verdict-format}}` | `fill-verdict-format` | static | Returns: `"Verdict: APPROVE | REQUEST_CHANGES | BLOCK\nReasoning: <one paragraph>\nIssues: <list or none>"`. |
| `{{blocker-description}}` | `fill-blocker-description` | `(getf task-spec :blocker)` | Returns the blocker text or `"(no blocker described)"`. |
| `{{available-resources}}` | `fill-available-resources` | system + budget | Returns system context + budget remaining as formatted string. |
| `{{suggested-paths}}` | `fill-suggested-paths` | static per scenario | Returns unblock suggestions. For `:unblock`: `"1. Re-read AGENTS.md for updated context\n2. Check OptMem for shared notes\n3. Request help from a sibling role\n4. Escalate to PM"`. |
| `{{fragment-journal}}` | `fill-fragment-journal` | `(getf task-spec :fragment-journal-path)` | Returns the journal path or `"(no journal path)"`. |
| `{{resume-hint}}` | `fill-resume-hint` | `(getf task-spec :resume-hint)` | Returns resume hint or `"Re-read your last inbox messages and continue."`. |
| `{{value-captured}}` | `fill-value-captured` | `(getf task-spec :value-captured)` | Returns work summary or `"(summarize what was accomplished)"`. |
| `{{aesthetic-brief}}` | `fill-aesthetic-brief` | beans-aesthetic role table | Returns the aesthetic direction for the role. See §4.4. |
| `{{visual-references}}` | `fill-visual-references` | `(getf task-spec :visual-references)` | Returns references or `"(none provided)"`. |
| `{{constraints}}` | `fill-constraints` | `(getf task-spec :constraints)` | Returns constraints or `"(none specified)"`. |
| `{{cost-audit-request}}` | `fill-cost-audit-request` | `(getf task-spec :audit-scope)` | Returns audit scope or `"Audit: squad cost tracking, husk quality, spoilage detection."`. |
| `{{resource-snapshot}}` | `fill-resource-snapshot` | `%gather-system-context` + budget | Returns formatted system + budget snapshot. |
| `{{budget}}` | `fill-budget` | budget gate | Returns `"Budget remaining: $X.XX / $1.00 daily"` or `"(budget tracking unavailable)"`. |
| `{{task-batch}}` | `fill-task-batch` | `(getf task-spec :batch)` | Returns batch task list as numbered items or `"(no batch tasks)"`. |
| `{{roles-active}}` | `fill-roles-active` | `prompt-dimensions-roles-active` | Returns `"- role-name"` bullets for each active role. |

### 4.3 Bean vocabulary table

Static table from beans-aesthetic.md, per role:

```lisp
(defparameter *bean-vocabulary*
  '((:pm
     "You are the Planter. Plant beans in role pods. Cultivate, distribute, prune, cull stale chains. Vocabulary: plant, cultivate, distribute, prune, graft, cull.")
    (:designer
     "You are the Fermenter. Receive mixed beans, ferment them into design beans. Vocabulary: ferment, refine, distill, culture, age.")
    (:coder
     "You are the Mason. Digest task beans, lay them into structure. Vocabulary: lay, stack, mortar, fire, reject.")
    (:artist
     "You are the Transmuter. Consume design beans, transmute into artifact beans. Vocabulary: transmute, render, shape, kiln, glaze.")
    (:accountant
     "You are the Comptroller of Husks. Audit husk piles, track nutritional flow, detect spoilage and feral outbreaks. Vocabulary: audit, weigh, trace, cull, ration.")
    (:worker
     "You are the Forager. Digest whatever beans are planted. Vocabulary: forage, eat, gnaw, scavenge."))
  "Bean vernacular per role from beans-aesthetic.md.")
```

### 4.4 Aesthetic brief table

Static table from beans-aesthetic.md, per role:

```lisp
(defparameter *aesthetic-briefs*
  '((:pm "Dark palette. Monospace structural. The megastructure is the ecosystem. Pods are growth chambers.")
    (:designer "Beans are organic. Use biological language for machine processes. Dark palette, nutrient-dense, industrial.")
    (:coder "Stack digested bean-material into structure. Architectural vocabulary. Fire = compile/test.")
    (:artist "Glossy-organic meets matte-metal. Cysts, seeds, nutrient pellets in a biotech corridor. Dark palette.")
    (:accountant "The pathologist. Read husks to understand what the squad ate, what it refused, what made it sick.")
    (:worker "Forager aesthetic. High throughput, low specialization. Scavenge, gnaw, digest."))
  "Aesthetic direction per role from beans-aesthetic.md.")
```

### 4.5 Slot substitution

```lisp
(defun fill-bones (template dimensions &optional task-spec squad-name)
  "Fill all {{slot}} placeholders in TEMPLATE using bone fillers.
Returns the filled string with all slots replaced."
  (let ((result template))
    (loop for (slot-key . filler-fn) in *bone-fillers*
          for slot-name = (format nil "{{~A}}" (substitute #\- #\_ (string-downcase slot-key)))
          for value = (handler-case
                          (funcall filler-fn dimensions task-spec squad-name)
                        (error () "(fill failed)"))
          do (setf result (cl-ppcre:regex-replace-all
                           (format nil "\\{\\{~A\\}\\}" (string-downcase slot-key))
                           result
                           (or value ""))))
    result))
```

**Note**: Slot names in templates use hyphens (`{{agents-md-sections}}`), not
underscores. The filler keys use keywords with hyphens (`:agents-md-sections`).
The substitution matches `{{agents-md-sections}}` in the template.

---

## 5. Flesh Pass — LLM Once-Over

### 5.1 When to run

The flesh pass runs only when **all** of the following are true:

1. The assigned model for this role is **not** the local model (`gemma-4-12b`).
   The local model doesn't edit its own prompts.
2. The budget gate passes — there is remaining budget for the estimated cost
   of the flesh pass.
3. The prompt is **not** cache-hit — the same dimension combination has not
   already produced this prompt (deterministic bones mean identical dimension
   values produce identical skeleton+bones output).

```lisp
(defun should-flesh-p (dimensions model budget-remaining estimated-cost)
  "Return T when the flesh pass should run."
  (and
   ;; Not local model
   (not (local-model-p model))
   ;; Budget allows
   (and budget-remaining
        (> budget-remaining estimated-cost))
   ;; Not cache hit (checked by caller)
   t))
```

### 5.2 Flesh model selection

The flesh model is the **cheapest available non-local model** — this may
differ from the role's assigned model. The flesh model just edits the prompt;
it doesn't need high capability.

```lisp
(defun select-flesh-model (budget-remaining)
  "Select the cheapest available non-local model for the flesh pass.
Returns a model spec plist or NIL."
  (loop for model in *flesh-model-chain*
        when (and (not (local-model-p (getf model :name)))
                  (or (null budget-remaining)
                      (> budget-remaining (getf model :est-cost))))
          return model
        finally (return nil)))

(defparameter *flesh-model-chain*
  '((:name "deepseek-v4-flash" :provider "openrouter" :est-cost 0.001)
    (:name "gpt-5.6-luna" :provider "github-copilot" :est-cost 0.001)
    (:name "nemotron-super:free" :provider "openrouter" :est-cost 0)
    (:name "gemma-4-12b" :provider "unsloth-local" :est-cost 0))
  "Cheapest-first model chain for flesh pass. The last entry is local —
only used as a final fallback and only if the role allows local models.")
```

### 5.3 Flesh prompt

The flesh model receives a system prompt instructing it to edit the assembled
skeleton+bones for coherence, plus the assembled prompt as the user message.

**System prompt** (sent to flesh model):

```
You are a prompt editor. You receive a structured prompt assembled from
templates and context data. Your job: edit for coherence, tighten language,
add missing transitions, fix tone. DO NOT restructure the prompt. DO NOT
add new sections. DO NOT remove sections. Preserve all {{slot}} values that
have been filled — they are factual, not stylistic. Return only the edited
prompt text. No commentary.
```

**User message**: The assembled skeleton+bones string.

### 5.4 Acceptance criteria for flesh output

The flesh model's response is accepted only when it **preserves structure**:

1. All section headers (`## N. Title`) from the skeleton are present in the
   output (count must match).
2. No new top-level headers (`#`) are added.
3. The output is non-empty and shorter than 2× the input length (prevents
   runaway expansion).

If the flesh output fails validation, the pre-flesh (skeleton+bones) prompt is
returned unchanged. The flesh failure is logged but does not block.

```lisp
(defun validate-flesh-output (pre-flesh post-flesh)
  "Return T when POST-FLESH is an acceptable edit of PRE-FLESH."
  (and
   (stringp post-flesh)
   (> (length post-flesh) 0)
   ;; Section count preserved
   (= (count-section-headers pre-flesh)
      (count-section-headers post-flesh))
   ;; No new top-level headers
   (<= (count-top-headers post-flesh)
       (count-top-headers pre-flesh))
   ;; Not absurdly longer
   (< (length post-flesh) (* 2 (length pre-flesh)))))
```

### 5.5 Flesh pass function

```lisp
(defun run-flesh-pass (assembled-prompt dimensions model budget-remaining)
  "Run the LLM once-over on ASSEMBLED-PROMPT.
Returns the edited prompt string, or the original if flesh fails/is skipped."
  (let ((flesh-model (select-flesh-model budget-remaining)))
    (if (null flesh-model)
        assembled-prompt  ; No model available — skip
        (let ((edited (invoke-flesh-model flesh-model assembled-prompt)))
          (if (validate-flesh-output assembled-prompt edited)
              edited
              (progn
                (hngh.core:log-warn "Flesh pass validation failed, using pre-flesh prompt")
                assembled-prompt))))))
```

`invoke-flesh-model` shells out to the model via the existing AI tool hub or a
direct API call. The implementation should use the existing cost routing
infrastructure (faucet ladder). If no remote model is available (all 429/403),
the flesh pass is skipped and the pre-flesh prompt is returned.

---

## 6. Model Recommendations Block Format

The `{{model-recommendations}}` slot is filled with a markdown table matching
the format from `model-pareto.md` §5. The table shows each active role with its
assigned model, cost, estimated tokens, and estimated cost.

### 6.1 Table format

```markdown
## Model recommendations

| Role | Model | $/M | Est. tokens | Est. cost |
|---|---|---|---|---|
| PM | glm-5.2 | 0.40 | 50K | $0.02 |
| Designer | glm-5.2 | 0.40 | 50K | $0.02 |
| Coder | deepseek-v4-flash | 0.09 | 100K | $0.01 |
| Artist | glm-5.2 | 0.40 | 20K | $0.008 |
| Accountant | gemini-3.5-flash-lite | 0.30 | 10K | $0.003 |
| Worker | deepseek-v4-flash | 0.09 | 50K | $0.005 |

Total estimated cost: $0.066
Budget gate: passes ($1/day, $0.066 < remaining)
```

### 6.2 Filler function

```lisp
(defun fill-model-recommendations (dimensions task-spec squad-name)
  "Fill the {{model-recommendations}} slot with a model assignment table."
  (let ((roles (prompt-dimensions-roles-active dimensions))
        (rows '()))
    (dolist (role roles)
      (let* ((model (select-role-model role dimensions))
             (model-name (getf model :name))
             (cost-per-m (getf model :input-cost))
             (est-tokens (estimate-role-tokens role dimensions))
             (est-cost (/ (* cost-per-m est-tokens) 1000000.0)))
        (push (list role model-name cost-per-m est-tokens est-cost) rows)))
    (setf rows (nreverse rows))
    (with-output-to-string (s)
      (format s "## Model recommendations~%~%")
      (format s "| Role | Model | $/M | Est. tokens | Est. cost |~%")
      (format s "|---|---|---|---|---|~%")
      (let ((total 0))
        (dolist (row rows)
          (format s "| ~A | ~A | ~,2F | ~DK | $~,3F |~%"
                  (first row) (second row) (third row)
                  (floor (fourth row) 1000) (fifth row))
          (incf total (fifth row)))
        (format s "~%Total estimated cost: $~,3F~%" total)
        (let ((budget-remaining (getf (prompt-dimensions-system dimensions) :budget-remaining)))
          (format s "Budget gate: ~A~%"
                  (if (and budget-remaining (> budget-remaining total))
                      (format nil "passes ($1/day, $~,3F < remaining)" total)
                      "FAILED — downgrade models along fallback chain")))))))
```

### 6.3 Token estimation per role

```lisp
(defparameter *role-token-estimates*
  '((:pm          . 50000)
    (:designer    . 50000)
    (:coder       . 100000)
    (:artist      . 20000)
    (:accountant  . 10000)
    (:worker      . 50000))
  "Rough token estimates per role for cost projection.")

(defun estimate-role-tokens (role dimensions)
  "Return estimated token count for ROLE in the given scenario."
  (or (getf *role-token-estimates* role) 30000))
```

---

## 7. Functions

### 7.1 generate-prompt

**Extends**: `generate-pm-prompt` (Wave 1, C7)

**Signature**:
```lisp
(defun generate-prompt (dimensions &key (task-spec nil) (squad-name "squad")
                                       (budget-remaining nil) (force-flesh nil))
  "Procedurally assemble a role prompt from the prompt matrix.

DIMENSIONS — a prompt-dimensions struct with role, scenario, strategy,
  resources, squad-count, roles-active, lifetime, directory, system, purpose.
TASK-SPEC — optional plist with task details (:id, :title, :files, :acceptance,
  :preconditions, :review-criteria, :blocker, :fragment-journal-path, etc.).
  May be NIL for startup scenarios.
SQUAD-NAME — string, the squad identifier.
BUDGET-REMAINING — optional number, dollars remaining in daily budget.
  When NIL, flesh pass is skipped (no budget tracking).
FORCE-FLESH — when T, force the flesh pass even if cache-hit (for testing).

Returns a string containing the assembled prompt."
```

**Behavior**:
1. Select skeleton: `(get-skeleton (prompt-dimensions-role dimensions)
                                   (prompt-dimensions-scenario dimensions))`
2. If no skeleton matches, fall back to the STARTUP skeleton for the role.
   If no STARTUP skeleton matches, fall back to the PM STARTUP skeleton.
3. Check prompt cache: compute a cache key from the dimension values + task-spec.
   If cache-hit and `force-flesh` is NIL, return cached prompt (no flesh pass).
4. Fill bones: `(fill-bones skeleton dimensions task-spec squad-name)`.
5. Select model: `(select-role-model (prompt-dimensions-role dimensions) dimensions)`.
6. Determine if flesh should run:
   - Not local model? → continue
   - Budget allows (budget-remaining > estimated flesh cost)? → continue
   - Not cache-hit (or force-flesh)? → continue
   - If any condition fails, return skeleton+bones without flesh.
7. Run flesh pass: `(run-flesh-pass assembled-prompt dimensions model budget-remaining)`.
8. Store result in cache.
9. Return the prompt string.

**Return value**: string (the assembled prompt).

**Backward compatibility**: `generate-pm-prompt` calls `generate-prompt`:

```lisp
(defun generate-pm-prompt (goal &key (cwd (uiop:getcwd))
                                 (lifetime :ephemeral)
                                 (squad-name "squad")
                                 (model-config nil))
  "Backward-compatible entry point. Delegates to generate-prompt with
:role :pm :scenario :startup."
  (let ((dimensions (make-prompt-dimensions
                     :role :pm
                     :scenario :startup
                     :strategy (select-strategy-from-goal goal)
                     :resources :budget-50
                     :squad-count 1
                     :roles-active '(:pm)
                     :lifetime lifetime
                     :directory (select-directory cwd)
                     :system (select-system)
                     :purpose goal)))
    (generate-prompt dimensions :squad-name squad-name)))
```

### 7.2 select-role-model

**Signature**:
```lisp
(defun select-role-model (role dimensions)
  "Select the best model for ROLE from the Pareto table, checking VRAM,
budget, and time-sensitivity.

Returns a plist: (:name <string> :provider <string> :input-cost <number>
                  :output-cost <number> :capability <number> :local-p <boolean>)
or NIL if no model can be assigned."
```

**Behavior**:
1. Get the role's fallback chain from `*per-role-fallback-chains*`.
2. For each model in the chain (primary → fallback → ... → local):
   a. If model is local: check VRAM available via `squad-resources:free-vram-mb`
      and `squad-resources:model-vram-mb`. Check that the role allows local
      models (see local-model policy below).
   b. If model is remote: check budget remaining >= estimated cost. If
      `budget-remaining` is NIL (unknown), assume sufficient.
   c. If model is K3: check PM authorization flag (never auto-assign K3).
   d. If model is `:free`: check daily free-tier count (via ai-tool-hub cost log
      or a simple counter). If > 950/day, skip.
   e. Check time-sensitivity from `prompt-dimensions-scenario`:
      - `:startup`, `:task-assign`, `:unblock` → time-sensitive → skip local
        unless it's the last resort.
      - `:status-check`, `:shutdown` → not time-sensitive → local is OK.
      - `:review` → time-sensitive for PM/Designer, OK for Accountant/Worker.
   f. If all gates pass: return model spec.
3. If nothing passes: return NIL (role cannot be dispatched).

**Local-model policy** (from squad-startup-automation.md §5):

| Role | Local model allowed? | When? |
|---|---|---|
| `:pm` | never (last resort only) | PM decisions are time-sensitive |
| `:designer` | creative only | creative riffing, aesthetic exploration, not structural design |
| `:coder` | simple only | fixture generation, mechanical edits, not architecture |
| `:artist` | never | creative quality matters |
| `:accountant` | procedural only | counting, file scanning, not analysis |
| `:worker` | queued only | background batch tasks, not blocking |

### 7.3 Per-role fallback chain

Static table from model-pareto.md §3:

```lisp
(defparameter *per-role-fallback-chains*
  '((:pm
     ((:name "glm-5.2" :provider "openrouter" :input-cost 0.40 :output-cost 0.40 :capability 8.5 :local-p nil)
      (:name "kimi-k2.6" :provider "kimi-coding" :input-cost 0.60 :output-cost 0.60 :capability 8.0 :local-p nil)
      (:name "nemotron-ultra:free" :provider "openrouter" :input-cost 0 :output-cost 0 :capability 6.5 :local-p nil)
      (:name "gemma-4-12b" :provider "unsloth-local" :input-cost 0 :output-cost 0 :capability 6.0 :local-p t)))
    (:designer
     ((:name "glm-5.2" :provider "openrouter" :input-cost 0.40 :output-cost 0.40 :capability 8.5 :local-p nil)
      (:name "kimi-k2.6" :provider "kimi-coding" :input-cost 0.60 :output-cost 0.60 :capability 8.0 :local-p nil)
      (:name "nemotron-super:free" :provider "openrouter" :input-cost 0 :output-cost 0 :capability 6.0 :local-p nil)
      (:name "gemma-4-12b" :provider "unsloth-local" :input-cost 0 :output-cost 0 :capability 6.0 :local-p t)))
    (:coder
     ((:name "deepseek-v4-flash" :provider "openrouter" :input-cost 0.09 :output-cost 0.09 :capability 7.0 :local-p nil)
      (:name "gpt-5.6-luna" :provider "github-copilot" :input-cost 0.10 :output-cost 0.10 :capability 7.5 :local-p nil)
      (:name "kimi-k2.6" :provider "kimi-coding" :input-cost 0.60 :output-cost 0.60 :capability 8.0 :local-p nil)
      (:name "nemotron-super:free" :provider "openrouter" :input-cost 0 :output-cost 0 :capability 6.0 :local-p nil)
      (:name "gemma-4-12b" :provider "unsloth-local" :input-cost 0 :output-cost 0 :capability 6.0 :local-p t)))
    (:artist
     ((:name "glm-5.2" :provider "openrouter" :input-cost 0.40 :output-cost 0.40 :capability 8.5 :local-p nil)
      (:name "deepseek-v4-pro" :provider "openrouter" :input-cost 0.435 :output-cost 0.435 :capability 8.0 :local-p nil)
      (:name "nemotron-super:free" :provider "openrouter" :input-cost 0 :output-cost 0 :capability 6.0 :local-p nil)))
    (:accountant
     ((:name "gemini-3.5-flash-lite" :provider "gemini" :input-cost 0.30 :output-cost 0.30 :capability 6.5 :local-p nil)
      (:name "nemotron-nano:free" :provider "openrouter" :input-cost 0 :output-cost 0 :capability 5.0 :local-p nil)
      (:name "gemma-4-12b" :provider "unsloth-local" :input-cost 0 :output-cost 0 :capability 6.0 :local-p t)))
    (:worker
     ((:name "deepseek-v4-flash" :provider "openrouter" :input-cost 0.09 :output-cost 0.09 :capability 7.0 :local-p nil)
      (:name "gpt-5.6-luna" :provider "github-copilot" :input-cost 0.10 :output-cost 0.10 :capability 7.5 :local-p nil)
      (:name "nemotron-super:free" :provider "openrouter" :input-cost 0 :output-cost 0 :capability 6.0 :local-p nil)
      (:name "gemma-4-12b" :provider "unsloth-local" :input-cost 0 :output-cost 0 :capability 6.0 :local-p t))))
  "Per-role model fallback chains from model-pareto.md §3.
Ordered cheapest-capable first. Artist has no local fallback (never local).")
```

**Fallback chain evaluation** (runtime, not static):

```lisp
(defun evaluate-fallback-chain (role dimensions budget-remaining)
  "Try each model in the role's fallback chain. Return the first that passes
all gates, or NIL if exhausted."
  (let ((chain (getf *per-role-fallback-chains* role))
        (scenario (prompt-dimensions-scenario dimensions))
        (vram-free (getf (prompt-dimensions-system dimensions) :vram-free-mb)))
    (loop for model in chain
          for passes = (check-model-gates model scenario budget-remaining vram-free role)
          when passes return model
          finally (return nil))))

(defun check-model-gates (model scenario budget-remaining vram-free role)
  "Return T when MODEL passes all dispatch gates for this ROLE/SCENARIO."
  (cond
    ;; Local model: check VRAM + role policy
    ((getf model :local-p)
     (and (or (and vram-free
                   (>= vram-free (squad-resources:model-vram-mb (getf model :name))))
              (null vram-free))  ; no telemetry → don't block
          (role-allows-local-p role scenario)))
    ;; Remote model: check budget
    (t
     (let ((est-cost (estimate-model-cost model role)))
       (or (null budget-remaining)  ; unknown budget → don't block
           (>= budget-remaining est-cost))))))

(defun role-allows-local-p (role scenario)
  "Return T when the role allows local models for this scenario."
  (case role
    (:pm nil)  ; never (last resort, handled by caller)
    (:artist nil)  ; never
    (:designer (member scenario '(:status-check :shutdown)))
    (:coder (member scenario '(:status-check :shutdown)))
    (:accountant (member scenario '(:status-check :shutdown)))
    (:worker (member scenario '(:status-check :shutdown :task-assign)))
    (t nil)))
```

### 7.4 Prompt caching

The prompt cache prevents redundant flesh passes for identical dimension
combinations. Since bones are deterministic, the same dimension values +
task-spec produce the same skeleton+bones. The cache stores the final prompt
(flesh or no-flesh) keyed by a hash of the dimension values.

```lisp
(defparameter *prompt-cache* (make-hash-table :test 'equal)
  "Cache of generated prompts keyed by dimension hash.")

(defun prompt-cache-key (dimensions task-spec)
  "Compute a cache key from DIMENSIONS and TASK-SPEC.
Returns a string suitable as a hash table key."
  (let ((role (prompt-dimensions-role dimensions))
        (scenario (prompt-dimensions-scenario dimensions))
        (strategy (prompt-dimensions-strategy dimensions))
        (resources (prompt-dimensions-resources dimensions))
        (lifetime (prompt-dimensions-lifetime dimensions))
        (purpose (prompt-dimensions-purpose dimensions))
        (task-id (getf task-spec :id)))
    (format nil "~A:~A:~A:~A:~A:~A:~A"
            role scenario strategy resources lifetime purpose
            (or task-id ""))))

(defun cache-get (dimensions task-spec)
  "Return cached prompt for this dimension combo, or NIL."
  (gethash (prompt-cache-key dimensions task-spec) *prompt-cache*))

(defun cache-put (dimensions task-spec prompt)
  "Store PROMPT in the cache for this dimension combo."
  (setf (gethash (prompt-cache-key dimensions task-spec) *prompt-cache*) prompt))

(defun cache-clear ()
  "Clear the prompt cache."
  (clrhash *prompt-cache*))
```

**Cache semantics**:
- The cache key includes role, scenario, strategy, resources, lifetime,
  purpose, and task-id. These are the values that determine the skeleton
  selection and bone content.
- The directory and system dimensions are **not** in the cache key for the
  base case because they're read fresh each time (AGENTS.md may have changed).
  However, the cache stores a hash of the assembled bones, and if the hash
  matches, the flesh pass is skipped even if the cache entry's bones differ
  (the flesh edit applies to the content, not the structure).
- For the initial implementation, the cache key includes the full dimension
  hash. A simpler approach: hash the assembled skeleton+bones string. If the
  hash matches a cached entry, skip the flesh pass and return the cached
  fleshed prompt. If the bones differ (AGENTS.md changed), the hash won't
  match and a new flesh pass runs.

```lisp
(defun cache-key-from-bones (assembled-prompt)
  "Hash the assembled skeleton+bones string for cache keying."
  (sxhash assembled-prompt))
```

---

## 8. Package and Export Changes

### 8.1 `src/packages.lisp` — extend `:hngh.plugins.hngh-up`

Add to the `(:export ...)` list:

```lisp
           #:generate-prompt
           #:select-role-model
           #:make-prompt-dimensions
           #:prompt-dimensions
           #:prompt-dimensions-p
                   #:prompt-dimensions-role
                   #:prompt-dimensions-scenario
                   #:prompt-dimensions-strategy
                   #:prompt-dimensions-resources
                   #:prompt-dimensions-squad-count
                   #:prompt-dimensions-roles-active
                   #:prompt-dimensions-lifetime
                   #:prompt-dimensions-directory
                   #:prompt-dimensions-system
                   #:prompt-dimensions-purpose
           #:get-skeleton
                   #:fill-bones
           #:should-flesh-p
           #:run-flesh-pass
           #:cache-clear
           #:*per-role-fallback-chains*
           #:*skeleton-library*)
```

No new packages needed. All functions live in `:hngh.plugins.hngh-up`.

### 8.2 `hngh.asd` — no changes

No new files. The plugin extends `src/plugins/hngh-up.lisp` (already in the
component list). Tests extend `tests/unit/test-hngh-up.lisp` (already listed).

---

## 9. Test Fixture Spec

All tests extend `tests/unit/test-hngh-up.lisp`. The test suite is
`:hngh.hngh-up` (already defined). Tests use the existing FiveAM framework
and the existing `%c7-tmp-project` fixture builder.

### 9.1 Fixture builders

**`%d5-tmp-project`** — extends `%c7-tmp-project` with:
- A `docs/design/beans-aesthetic.md` stub (for bean vocabulary)
- A `docs/design/model-pareto.md` stub (for model table)
- A `Makefile` with `build:` and `test:` targets
- A `.hermes/plans/` with 2 plan files

```lisp
(defun %d5-tmp-project ()
  "Create a fresh synthetic project for prompt matrix tests.
Returns the directory pathname."
  (let ((dir (%c7-tmp-project)))  ; reuse existing fixture
    ;; Add Makefile
    (with-open-file (s (merge-pathnames "Makefile" dir)
                       :direction :output :if-exists :supersede
                       :if-does-not-exist :create)
      (write-string "build:\n\techo built\ntest:\n\techo tested\n" s))
    ;; Add second plan
    (with-open-file (s (merge-pathnames
                        ".hermes/plans/2026-08-03_second-plan.md" dir)
                       :direction :output :if-exists :supersede
                       :if-does-not-exist :create)
      (write-string "# Second Plan\n\nAnother plan for testing.\n" s))
    dir))
```

### 9.2 Test cases

#### T1: Per-dimension value selection

```lisp
(test d5-dimension-selection
  "Dimension selection functions return correct values from context."
  (let ((dir (%d5-tmp-project)))
    (unwind-protect
         (let ((dims (make-prompt-dimensions
                      :role :coder
                      :scenario :task-assign
                      :strategy :feature-sprint
                      :resources :budget-50
                      :squad-count 3
                      :roles-active '(:pm :designer :coder)
                      :lifetime :ephemeral
                      :directory (select-directory dir)
                      :system (select-system)
                      :purpose "implement the watcher plugin")))
           (is (eq (prompt-dimensions-role dims) :coder))
           (is (eq (prompt-dimensions-scenario dims) :task-assign))
           (is (eq (prompt-dimensions-strategy dims) :feature-sprint))
           (is (= (prompt-dimensions-squad-count dims) 3))
           (is (equal (prompt-dimensions-roles-active dims) '(:pm :designer :coder)))
           (is (string= (prompt-dimensions-purpose dims) "implement the watcher plugin")))
      (%c7-cleanup dir))))
```

#### T2: Skeleton structure assertion

```lisp
(test d5-skeleton-selection
  "get-skeleton returns the correct template for each role×scenario pair."
  ;; All 36 combinations return non-NIL
  (dolist (role '(:pm :designer :coder :artist :accountant :worker))
    (dolist (scenario '(:startup :task-assign :status-check :review :shutdown :unblock))
      (let ((skeleton (get-skeleton role scenario)))
        (is (not (null skeleton))
            "No skeleton for ~A×~A" role scenario)
        (when skeleton
          ;; Skeleton contains at least one {{slot}} placeholder
          (is (search "{{" skeleton)
              "Skeleton for ~A×~A has no slots" role scenario)))))
  ;; PM startup skeleton contains the orientation directive
  (is (search "Orientation" (get-skeleton :pm :startup)))
  ;; Coder task-assign skeleton contains task-id slot
  (is (search "{{task-id}}" (get-skeleton :coder :task-assign)))
  ;; Review skeleton contains review-criteria slot
  (is (search "{{review-criteria}}" (get-skeleton :coder :review)))
  ;; Shutdown skeleton contains fragment-journal slot
  (is (search "{{fragment-journal}}" (get-skeleton :pm :shutdown)))
  ;; Unblock skeleton contains blocker-description slot
  (is (search "{{blocker-description}}" (get-skeleton :coder :unblock))))
```

#### T3: Bone-filling assertion

```lisp
(test d5-bone-filling
  "fill-bones replaces all {{slot}} placeholders with deterministic values."
  (let ((dir (%d5-tmp-project)))
    (unwind-protect
         (let* ((dims (make-prompt-dimensions
                       :role :pm
                       :scenario :startup
                       :strategy :duo-review
                       :resources :local-only
                       :squad-count 1
                       :roles-active '(:pm)
                       :lifetime :ephemeral
                       :directory (select-directory dir)
                       :system (select-system)
                       :purpose "review plugins"))
                (skeleton (get-skeleton :pm :startup))
                (filled (fill-bones skeleton dims nil "test-squad")))
           ;; No unfilled {{slot}} placeholders remain
           (is (not (search "{{" filled))
               "Unfilled slots remain: ~A" filled)
           ;; Role name appears
           (is (search "pm" filled))
           ;; Squad name appears
           (is (search "test-squad" filled))
           ;; Goal appears
           (is (search "review plugins" filled))
           ;; Lifetime policy appears
           (is (search "ephemeral" (string-downcase filled)))
           ;; System context appears (GPU/VRAM)
           (is (search "GPU" filled)))
      (%c7-cleanup dir))))
```

#### T4: Bone-filling with task-spec

```lisp
(test d5-bone-filling-with-task-spec
  "fill-bones uses task-spec values when provided."
  (let ((dir (%d5-tmp-project)))
    (unwind-protect
         (let* ((task-spec '(:id "w2" :title "File watcher plugin"
                             :files ("src/plugins/file-watcher.lisp")
                             :acceptance "make test green"
                             :preconditions "config-watcher exists"))
                (dims (make-prompt-dimensions
                       :role :coder
                       :scenario :task-assign
                       :strategy :feature-sprint
                       :resources :budget-50
                       :squad-count 3
                       :roles-active '(:pm :designer :coder)
                       :lifetime :ephemeral
                       :directory (select-directory dir)
                       :system (select-system)
                       :purpose "implement file watcher"))
                (skeleton (get-skeleton :coder :task-assign))
                (filled (fill-bones skeleton dims task-spec "test-squad")))
           (is (not (search "{{" filled)))
           (is (search "w2" filled))
           (is (search "File watcher plugin" filled))
           (is (search "file-watcher.lisp" filled))
           (is (search "make test green" filled)))
      (%c7-cleanup dir))))
```

#### T5: Flesh skip when local model

```lisp
(test d5-flesh-skip-when-local
  "Flesh pass is skipped when the assigned model is local (gemma-4-12b)."
  (let ((dir (%d5-tmp-project)))
    (unwind-protect
         (let* ((dims (make-prompt-dimensions
                       :role :worker
                       :scenario :startup
                       :strategy :nightly-audit
                       :resources :local-only
                       :squad-count 1
                       :roles-active '(:worker)
                       :lifetime :continual
                       :directory (select-directory dir)
                       :system (list :gpu-count 1 :vram-total-mb 24576 :vram-free-mb 16384)
                       :purpose "batch tasks"))
                (model (select-role-model :worker dims)))
           ;; Worker with local-only resources gets local model
           (is (getf model :local-p))
           ;; should-flesh-p returns NIL for local model
           (is (null (should-flesh-p dims (getf model :name) 1.00 0.001)))
           ;; generate-prompt returns the pre-flesh prompt (no flesh)
           (let ((prompt (generate-prompt dims :squad-name "test-squad"
                                          :budget-remaining 1.00)))
             (is (search "Worker" prompt))
             (is (search "batch tasks" prompt))))
      (%c7-cleanup dir))))
```

#### T6: Flesh skip when no budget

```lisp
(test d5-flesh-skip-when-no-budget
  "Flesh pass is skipped when budget-remaining is NIL or below estimated cost."
  (let ((dir (%d5-tmp-project)))
    (unwind-protect
         (let* ((dims (make-prompt-dimensions
                       :role :coder
                       :scenario :startup
                       :strategy :feature-sprint
                       :resources :budget-50
                       :squad-count 3
                       :roles-active '(:pm :designer :coder)
                       :lifetime :ephemeral
                       :directory (select-directory dir)
                       :system (select-system)
                       :purpose "implement watcher")))
           ;; Budget NIL → no flesh
           (is (null (should-flesh-p dims "deepseek-v4-flash" nil 0.001)))
           ;; Budget 0 → no flesh
           (is (null (should-flesh-p dims "deepseek-v4-flash" 0 0.001)))
           ;; Budget sufficient → flesh
           (is (should-flesh-p dims "deepseek-v4-flash" 1.00 0.001)))
      (%c7-cleanup dir))))
```

#### T7: Model selection per role

```lisp
(test d5-model-selection-per-role
  "select-role-model returns the correct primary model for each role."
  ;; PM gets glm-5.2 (frontier)
  (let ((model (select-role-model :pm
                                   (make-prompt-dimensions
                                    :role :pm :scenario :startup
                                    :strategy :duo-review :resources :budget-200
                                    :squad-count 2 :roles-active '(:pm :coder)
                                    :lifetime :ephemeral
                                    :directory (list :cwd (uiop:getcwd))
                                    :system (list :vram-free-mb 16384)
                                    :purpose "review"))))
    (is (search "glm-5.2" (getf model :name))))
  ;; Coder gets deepseek-v4-flash (cheapest capable)
  (let ((model (select-role-model :coder
                                   (make-prompt-dimensions
                                    :role :coder :scenario :startup
                                    :strategy :feature-sprint :resources :budget-200
                                    :squad-count 3 :roles-active '(:pm :coder :worker)
                                    :lifetime :ephemeral
                                    :directory (list :cwd (uiop:getcwd))
                                    :system (list :vram-free-mb 16384)
                                    :purpose "implement"))))
    (is (search "deepseek-v4-flash" (getf model :name))))
  ;; Artist never gets local model
  (let ((model (select-role-model :artist
                                   (make-prompt-dimensions
                                    :role :artist :scenario :startup
                                    :strategy :design-fork :resources :local-only
                                    :squad-count 2 :roles-active '(:pm :artist)
                                    :lifetime :ephemeral
                                    :directory (list :cwd (uiop:getcwd))
                                    :system (list :vram-free-mb 16384)
                                    :purpose "design"))))
    (is (not (getf model :local-p)))
    (is (search "glm-5.2" (getf model :name)))))  ; falls back to cheapest non-local
```

#### T8: Model fallback chain

```lisp
(test d5-model-fallback-chain
  "Fallback chain degrades correctly when primary is unavailable."
  ;; When budget is 0, remote models fail budget gate, chain falls to local
  (let ((model (select-role-model :worker
                                   (make-prompt-dimensions
                                    :role :worker :scenario :shutdown
                                    :strategy :nightly-audit :resources :local-only
                                    :squad-count 1 :roles-active '(:worker)
                                    :lifetime :continual
                                    :directory (list :cwd (uiop:getcwd))
                                    :system (list :vram-free-mb 16384)
                                    :purpose "shutdown"))))
    ;; Worker shutdown allows local model
    (is (getf model :local-p))))
```

#### T9: Prompt caching

```lisp
(test d5-prompt-cache
  "Same dimension combo returns cached prompt (no second flesh pass)."
  (cache-clear)
  (let ((dir (%d5-tmp-project)))
    (unwind-protect
         (let* ((dims (make-prompt-dimensions
                       :role :pm :scenario :startup
                       :strategy :duo-review :resources :budget-50
                       :squad-count 1 :roles-active '(:pm)
                       :lifetime :ephemeral
                       :directory (select-directory dir)
                       :system (select-system)
                       :purpose "test caching"))
                (prompt1 (generate-prompt dims :squad-name "cache-test"
                                          :budget-remaining nil))  ; no flesh
                (prompt2 (generate-prompt dims :squad-name "cache-test"
                                          :budget-remaining nil)))
           ;; Both calls return the same prompt
           (is (string= prompt1 prompt2)))
      (cache-clear)
      (%c7-cleanup dir))))
```

#### T10: generate-pm-prompt backward compatibility

```lisp
(test d5-generate-pm-prompt-backward-compat
  "generate-pm-prompt still works and delegates to generate-prompt."
  (let ((dir (%d5-tmp-project)))
    (unwind-protect
         (let ((prompt (hngh.plugins.hngh-up:generate-pm-prompt
                        "review plugins"
                        :cwd dir :lifetime :ephemeral
                        :squad-name "compat-test")))
           (is (search "Orientation" prompt))
           (is (search "review plugins" prompt))
           (is (search "compat-test" prompt))
           (is (search "Lifetime" prompt)))
      (%c7-cleanup dir))))
```

#### T11: All 36 skeletons fill without error

```lisp
(test d5-all-skeletons-fill
  "Every skeleton in the library fills without leaving unfilled slots or crashing."
  (let ((dir (%d5-tmp-project)))
    (unwind-protect
         (let ((dims (make-prompt-dimensions
                       :role :pm :scenario :startup
                       :strategy :duo-review :resources :budget-50
                       :squad-count 3 :roles-active '(:pm :designer :coder)
                       :lifetime :ephemeral
                       :directory (select-directory dir)
                       :system (select-system)
                       :purpose "test all skeletons")))
           (dolist (role '(:pm :designer :coder :artist :accountant :worker))
             (setf (prompt-dimensions-role dims) role)
             (dolist (scenario '(:startup :task-assign :status-check
                                 :review :shutdown :unblock))
               (setf (prompt-dimensions-scenario dims) scenario)
               (let* ((skeleton (get-skeleton role scenario))
                      (filled (fill-bones skeleton dims nil "all-skeletons-test")))
                 (is (not (null filled))
                     "Skeleton ~A×~A filled to NIL" role scenario)
                 (is (not (search "{{" filled))
                     "Skeleton ~A×~A has unfilled slots: ~A"
                     role scenario filled)))))
      (%c7-cleanup dir))))
```

---

## 10. Implementation Notes

### 10.1 Extension approach

The implementation extends `src/plugins/hngh-up.lisp` by adding:
1. The `prompt-dimensions` struct (after the existing state section).
2. The `*skeleton-library*` hash table and `*bone-fillers*` alist (after the struct).
3. The 36 skeleton templates (populated in an `initialize-skeletons` function
   called at load time or lazily on first access).
4. The bone filler functions (after the existing C7 helpers — reuse
   `%scan-plans`, `%scan-design-docs`, `%read-roadmap-status`,
   `%gather-system-context`, `%run-optmem-wake`, `%format-lifetime-policy`).
5. The flesh pass functions (after bone fillers).
6. `generate-prompt` (after `generate-pm-prompt`).
7. `generate-pm-prompt` is modified to delegate to `generate-prompt` (but
   preserves its existing signature and behavior — tests from Wave 1 must
   still pass).
8. `select-role-model` and fallback chain evaluation.
9. Prompt cache.

### 10.2 Dependency on existing code

| Existing function | Reused by |
|---|---|
| `%scan-plans` | `fill-plans` |
| `%scan-design-docs` | `fill-design-docs` |
| `%read-roadmap-status` | `fill-roadmap-status` |
| `%gather-system-context` | `fill-system-context` |
| `%run-optmem-wake` | `fill-optmem-notes` |
| `%format-lifetime-policy` | `fill-lifetime-policy` |
| `gather-agents-md-context` | `fill-agents-md-sections`, `fill-agents-md-key-facts` |
| `squad-resources:model-vram-mb` | `select-role-model` VRAM gate |
| `squad-resources:free-vram-mb` | `select-role-model` VRAM gate |
| `squad-resources:local-model-p` | `should-flesh-p` |

### 10.3 Flesh model invocation

`invoke-flesh-model` should use the existing AI tool hub (`hngh.plugins.ai-tool-hub:invoke`)
or the cost routing infrastructure. If neither is available (e.g., running
standalone without the daemon), the flesh pass is skipped and the pre-flesh
prompt is returned. This keeps the prompt matrix usable without a running
daemon.

```lisp
(defun invoke-flesh-model (model-spec prompt-text)
  "Send PROMPT-TEXT to the model in MODEL-SPEC for editing.
Returns the edited text, or NIL if invocation fails."
  (handler-case
      (let ((tool (find-flesh-tool model-spec)))
        (if tool
            (let ((result (hngh.plugins.ai-tool-hub:invoke
                           tool
                           (list :system-prompt *flesh-system-prompt*
                                 :user-message prompt-text))))
              (getf result :output))
            nil))
    (error () nil)))
```

### 10.4 Thread safety

The prompt cache (`*prompt-cache*`) is a simple hash table. For the initial
implementation, no locking is needed — prompt generation happens at squad
startup, not in a hot loop. If concurrent access becomes a concern (Wave 6+
with multiple squads), wrap cache access in a mutex.

### 10.5 Error handling

- Missing skeleton → fall back to PM STARTUP skeleton (never crash).
- Missing AGENTS.md → fill with `"(no AGENTS.md found)"` (already handled).
- Missing OptMem → fill with `"(no OptMem notes available)"`.
- Missing task-spec → fill task slots with `"(no task assigned)"`.
- Flesh model invocation failure → return pre-flesh prompt.
- Flesh validation failure → return pre-flesh prompt.
- `select-role-model` returns NIL → log warning, use `:gemma-4-12b` as
  absolute fallback (better a local model than no model).

---

## 11. Acceptance Criteria

1. `generate-prompt` produces a structured prompt for all 36 role×scenario
   combinations with no unfilled `{{slot}}` placeholders.
2. `select-role-model` returns the Pareto-optimal model for each role given
   budget and VRAM constraints.
3. The flesh pass is skipped when the model is local, budget is exhausted,
   or the prompt is cache-hit.
4. `generate-pm-prompt` backward compatibility — all existing Wave 1 tests
   pass unchanged.
5. `make test` green (new count: 1393 + ~11 new tests = ~1404).

---

## 12. Preconditions and Postconditions

**Preconditions** (checked at dispatch time):
- `generate-pm-prompt` exists in `hngh-up.lisp` (Wave 1 done) ✓
- `beans-aesthetic.md` exists in `docs/design/` (Wave 4 done) ✓
- `squad-resources` plugin exports `model-vram-mb`, `free-vram-mb`,
  `local-model-p` ✓
- `agents-md` plugin exports `discover-agents-md`, `merge-agents-md` ✓

**Postconditions**:
- `generate-prompt` is callable with a `prompt-dimensions` struct
- All 36 skeletons are populated in `*skeleton-library*`
- `select-role-model` returns correct models from the Pareto table
- Flesh pass skips when local/no-budget/cache-hit
- `make test` green
- `generate-pm-prompt` backward compatibility maintained

---

## Attribution

Designer — glm-5.2, Hermes harness.
Model assignments per `docs/design/model-pareto.md` — Pareto frontier, per-role
fallback chains, quota and budget gates.
Bean vocabulary from `docs/design/beans-aesthetic.md` — produced by
gemma-4-12b (local, $0).