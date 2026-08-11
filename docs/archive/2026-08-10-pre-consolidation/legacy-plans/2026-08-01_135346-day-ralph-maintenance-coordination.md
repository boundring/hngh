# Day-Ralph and Maintenance Coordination Plan

> **For Hermes:** Implement only after this plan is reviewed. Use fixture-first tests and one bounded wave at a time.

**Goal:** Turn hngh's current serial local queue into a controlled day-work scheduler that can pause safely for system maintenance, while keeping package updates explicitly human-approved.

**Architecture:** Keep the existing `ai-orchestrator` persistent queue as the source of truth. Add a procedural maintenance coordinator that detects update conditions and gates dispatch. It must not invoke `pacman`, Cachy-Update, `sudo`, reboot, or external agentic CLIs. A later, separately approved package-operation design can consume its maintenance state.

**Tech stack:** SBCL, FiveAM, existing state store/event bus/scheduler, read-only `checkupdates`, file existence checks, and bounded subprocess wrappers.

---

## Evidence and decisions

- The live hngh queue is functional but has only `:queued`, `:running`, `:done`, and `:failed`; it has no dependencies, retry controls, pause state, lease, or cancellation. `src/plugins/ai-orchestrator.lisp:746-850`.
- It is serial: one queued task is selected per scheduler tick. This is a useful v1 concurrency boundary; preserve it.
- The current package operation path is **not safe for automatic full upgrades**. `upgrade-system` builds a list from `checkupdates`, then calls `InstallPackages`; the root daemon currently invokes `pacman -S --noconfirm --needed`, not `pacman -Syu`. Snapshot failure logs a warning and continues. `src/plugins/package-manager.lisp:370-428`; `src/system-daemon/main.c:164-193,274-327`.
- This host had 36 pending package updates at the most recent read-only probe, no pending kernel package update, no pacman database lock, and five existing pacnew files. The root filesystem is btrfs. These are observation facts, not authorization to mutate.
- The running hngh process comes from the mission-control tmux pane (`make run`); it is not an installed user systemd service. Hngh package/system units are not installed.
- Existing failed tasks establish two regression seams: a malformed direct-API JSON request and an unsupported `:opencode` tool path. Preserve their records; do not auto-retry historical failures.

## Locked v1 boundaries

1. **Queue any number of tasks.** The persistent queue has no artificial ten- or twelve-task limit. Any batch cap belongs only to a particular worker/runner invocation.
2. **Only the scheduler dispatches.** Submitters append validated task records; they do not execute tasks.
3. **No privileged mutation in Day-Ralph v1.** Updates, pacnew merges, service restarts, snapshot creation, reboot, and shutdown remain user actions after a human approval boundary.
4. **Maintenance state gates only the work that needs it; it never kills a running task.** A running local call gets its configured bounded timeout. `:requires-stable-system` tasks wait outside `:clear`; an asserted `:maintenance-active` window pauses all new dispatch. This avoids corrupting an in-flight queue record.
5. **Fail closed at the relevant boundary.** A malformed state file, an unreadable probe, a pacman lock, a stale running lease, or an unknown maintenance condition blocks privileged maintenance and `:requires-stable-system` work. It does not permanently halt ordinary local text-out work merely because an optional update probe is unavailable.
6. **Local task output remains reviewable.** Local models may draft plans, summaries, test fixtures, and research artifacts. They never autonomously apply code, system, or config changes.

---

## Work package A — queue data model and procedural control plane

### Task A1: Define a versioned task record and state vocabulary

**Files:**
- Modify: `src/plugins/ai-orchestrator.lisp`
- Modify: `tests/unit/test-task-driver.lisp`
- Modify: `docs/design/model-routing.md`
- Modify: `docs/project/next.md`

Add only data needed for controlled continuation:

```lisp
(:id 7
 :schema-version 2
 :task "..."
 :status :queued
 :policy (:route :local-12b)
 :authority :advisory
 :approval-at nil
 :depends-on ()
 :attempt 0
 :max-attempts 1
 :not-before nil
 :lease-until nil
 :blocked-reason nil
 :result nil :error nil
 :submitted-at <ut> :started-at nil :finished-at nil)
```

Allowed statuses: `:proposed`, `:queued`, `:blocked`, `:running`, `:done`, `:failed`, `:cancelled`. `:authority` is one of `:procedural`, `:advisory`, or `:approval`; it is separate from `:policy`, which selects a route/model. `:approval` entries require a human timestamp before dispatch.

**Acceptance criteria:**
- Existing v1 entries load with defaults and remain readable.
- `:proposed` records cannot dispatch; promotion to `:queued` is a separate explicit state transition.
- `:approval` records cannot dispatch without `:approval-at`.
- Unknown status, invalid authority, invalid dependency IDs, cyclic dependencies, non-string tasks, or invalid attempt bounds are rejected before persistence.
- `submit-task` still defaults to local routing, but no caller may pass a raw model name.
- Queue length is unbounded; no global cap is added.

### Task A2: Add pure eligibility selection

**Files:**
- Modify: `src/plugins/ai-orchestrator.lisp`
- Modify: `tests/unit/test-task-driver.lisp`

Create a pure selector, e.g. `next-eligible-task(queue now maintenance-state)`. It selects the oldest task only when:

- status is `:queued`;
- all `:depends-on` entries are `:done`;
- `:not-before` has elapsed;
- no other task has an unexpired `:running` lease;
- its `:authority` is not `:proposed`;
- if its `:authority` is `:approval`, `:approval-at` is a valid human timestamp;
- if the task is `:requires-stable-system`, maintenance state is `:clear`.

Ordinary text-out tasks remain eligible in `:maintenance-pending` or `:unknown`; only `:maintenance-active` pauses all new dispatch. A pacman lock blocks only `:requires-stable-system` work unless the user has explicitly asserted `:maintenance-active`.

If a dependency has `:failed` or `:cancelled`, set the dependent task to `:blocked` with a deterministic reason. Do not silently skip it forever.

**Acceptance criteria:** fixture tests prove ordering, dependency gating, permanent dependency failure, delayed retry, one-at-a-time execution, and that a missing optional update probe does not deadlock ordinary local text-out work.

### Task A3: Add pause/resume and stale-lease recovery

**Files:**
- Modify: `src/plugins/ai-orchestrator.lisp`
- Modify: `src/packages.lisp`
- Modify: `tests/unit/test-task-driver.lisp`

Expose narrow APIs: `pause-dispatch`, `resume-dispatch`, `dispatch-paused-p`, and `recover-stale-task-leases`.

`task-driver-tick` checks the pause gate before changing any task. A startup recovery pass converts only expired `:running` leases into `:blocked` with `:stale-lease`; it must never assume that a process survived a restart.

**Acceptance criteria:** a paused queue does not call `delegate`; a resumed queue does; malformed persisted pause state fails closed; stale records are visible for human triage rather than automatically re-run.

---

## Work package B — maintenance observer, no system mutation

### Task B1: Create a first-party maintenance coordinator plugin

**Files:**
- Create: `src/plugins/maintenance-coordinator.lisp`
- Modify: `src/packages.lisp`
- Modify: `hngh.asd`
- Modify: `src/core/main.lisp`
- Create: `tests/unit/test-maintenance-coordinator.lisp`

Mirror the `sentry` plugin’s minimal lifecycle and event-bus publishing. It has no AI calls and no privilege. It gathers a bounded observation record:

```lisp
(:state :clear|:maintenance-pending|:maintenance-active|:unknown
 :updates-count <integer-or-nil>
 :pacman-lock-p <boolean-or-nil>
 :pacnew-paths (<redacted/absolute paths>)
 :reboot-hint :none|:possible|:required|:unknown
 :observed-at <ut>
 :reason <short string>)
```

Probe interfaces are injected/stubbed in tests. Production probes are read-only and timeout-bounded:
- `checkupdates` (exit `0` means updates; exit `2` means no updates; other codes mean unknown)
- `/var/lib/pacman/db.lck` existence
- bounded pacnew/pacsave discovery under `/etc`
- optional, explicitly documented reboot hint provider; no guessed reboot claim if unavailable.

Publish `maintenance.state-changed` only when the normalized state changes.

**Acceptance criteria:** fixture tests cover updates present, no updates, lock held, command timeout, malformed command output, and missing tools. Any ambiguous probe yields `:unknown`, not `:clear`.

### Task B2: Gate the task driver on maintenance state

**Files:**
- Modify: `src/plugins/ai-orchestrator.lisp`
- Modify: `src/plugins/maintenance-coordinator.lisp`
- Modify: `tests/unit/test-task-driver.lisp`
- Modify: `tests/unit/test-maintenance-coordinator.lisp`

Policy:

| Maintenance state | Existing `:running` task | Ordinary local text-out work | `:requires-stable-system` work |
|---|---|---|---|
| `:clear` | allow bounded completion | dispatch | dispatch |
| `:maintenance-pending` | allow bounded completion | dispatch | pause |
| `:maintenance-active` | do not kill; wait for timeout | pause | pause |
| `:unknown` | do not kill; wait for timeout | dispatch | pause |

`maintenance-active` is a manually asserted state in v1, not inferred from a model or from a fuzzy process list. The user controls it through a narrow API/CLI later; initially tests and a direct Lisp call are sufficient.

**Acceptance criteria:** event-driven state change prevents a new normal task from dispatching; it preserves the queue record and explains the block. Returning to `:clear` restores eligibility without rewriting task history.

### Task B3: Record maintenance state durably and visibly

**Files:**
- Modify: `src/plugins/maintenance-coordinator.lisp`
- Modify: `docs/guides/mission-control.md`
- Modify: `docs/project/next.md`

Persist the last observation in `state/maintenance.lisp`. Add the state to an existing status surface, but do not build a new dashboard panel in this wave.

**Acceptance criteria:** restart rehydrates the last known condition as stale/unknown until a fresh probe completes; users can distinguish “no observation yet” from “clear.”

---

## Work package C — update workflow design, explicit approval only

### Task C1: Replace the misleading automatic-upgrade claim with a gated design

**Files:**
- Modify: `docs/design/hngh-design-spec.md`
- Modify: `docs/design/components.md`
- Modify: `docs/design/integrations.md`
- Modify: `docs/project/decisions.md`
- Modify: `docs/project/next.md`

Document the v1 lifecycle:

1. observer finds updates or an external update start;
2. coordinator publishes `:maintenance-pending` and pauses normal dispatch;
3. dashboard presents package count, pacnew list, lock state, running task summary, snapshot capability, and reboot hint;
4. human explicitly chooses to use Cachy-Update or another approved update command outside Hngh;
5. coordinator enters `:maintenance-active` only when the user declares the maintenance window or an observed pacman lock confirms it;
6. on completion, re-probe; surface pacnew files, post-update service/reboot advisory, and breakage report for review;
7. only a human clears the maintenance window and resumes normal work.

Correct the old implication that Hngh can safely perform a system upgrade today. It cannot.

**Acceptance criteria:** every document says privileged mutation is approval-gated, `pacman -Syu` semantics are not conflated with installing a precomputed list, and snapshot failure is a hard stop in any future automated design.

### Task C2: Write a separate privileged-operations ADR before implementation

**Files:**
- Create: `docs/design/adr/NNNN-privileged-maintenance-operations.md` (choose the next project ADR number after inspecting the directory)
- Modify: `docs/project/next.md`

This ADR must decide, before code:
- exact command owner and authorization path;
- transaction semantics (`pacman -Syu` versus package list);
- preflight snapshot requirement and the supported btrfs/snapper topology;
- pacnew policy (report only first; no blind merge);
- durable operation journal and recovery after crash/reboot;
- timeout, cancellation, lock handling, reboot declaration, and post-flight verification;
- system daemon hardening: eliminate shell command strings and `--noconfirm` for unattended generic package operations.

**Acceptance criteria:** no implementation begins until this ADR is accepted. The ADR explicitly calls out bricking risks and lacks no user approval boundary.

---

## Day-task routing policy after A+B

- **Tier 0, procedural:** queue validation, dependency checks, leases, maintenance probes, pacman-lock checks, context/spend hard stops, state transitions, event journaling. No model calls.
- **Tier 1, local $0:** source-grounded summaries, task decomposition, artifact critique, test-plan drafts, post-update report summaries. Text-out/review-only; prompt target 100–350 words.
- **Tier 2, cheap remote:** bounded design review or implementation planning after `llm-budget` admits the call. One complete wave per request; no polling loop.
- **Tier 3, Terra/GLM/Kimi:** narrow architecture forks or stubborn debugging only. Kimi is not the default because its repeat tool-call stalls are observed.
- **Human-only:** any privileged operation, update execution, pacnew merge, service restart, snapshot, reboot, destructive task cancellation, route/budget policy change, or promotion of generated code/config.

---

## Immediate operational recommendation

Do **not** assign the current CachyOS update to Day-Ralph for completion. The safe action today is observation and planning. The host has pending non-kernel updates, five existing pacnew files, no current pacman lock, and no pre-update restart advisory. Run Cachy-Update interactively when ready; allow it to present Arch news and its post-update checks. Before doing so, manually pause normal hngh dispatch or simply ensure the queue is empty, since the new coordinator does not exist yet.

## Verification gates

For each implementation wave:

```sh
make test > /tmp/hngh-make-test.log 2>&1
grep -E 'Pass:|Fail:|Skip:' /tmp/hngh-make-test.log | tail -5
git diff --check
git status --short
```

Add targeted FiveAM tests before each code change. Run the focused suite first, then `make test`. Do not execute Cachy-Update, pacman, snapshot commands, service restart commands, or reboot commands as verification.

## Risks

- A user-space process cannot reliably infer every update/reboot condition. Unknown must block dispatch, not clear it.
- Hngh's root daemon is not installed and its existing command construction is inappropriate for unattended updates. Do not expose it as an automation path.
- A local model can produce plausible but unsafe operations text. Keep it advisory and source-grounded.
- The queue’s historical failures prove that retry must be error-classified, explicit, and opt-in. No blind automatic retry.
