# adversarial fresh-eyes review cadences for interfaces and agent work

Status: crystallized 2026-08-28 from research line `adversarial-review-patterns`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-adversarial-review-patterns.md.

# Contracted Research Line: Adversarial Fresh-Eyes Review Cadences for Interfaces and Agent Work

**Lifecycle:** contracting → crystallized

**Record status:** final structured summary / lasting record

**Applies to:** `hngh/hngh-automation` interfaces, agent workflows, automation runbooks, prompts, tool schemas, UI surfaces, and related operational flows.

---

## 1. Executive Summary

This line concludes with a durable recommendation:

> Institute a **scheduled, dual-track fresh-eyes review system** for human-facing interfaces and agent-facing workflow state.

The central review question is:

> Can a human or agent understand, continue, and complete this workflow using only the current visible state, explicit instructions, and machine-readable context — without relying on prior memory, hidden assumptions, or implementation history?

The goal is not merely “does it look okay?” but whether the system remains intelligible, resumable, and safe under fresh-context conditions.

This line crystallizes into three durable outcomes:

1. **Fresh-eyes review must be a cadence**, not an ad hoc activity.
2. **Human UX review and agent-state review must remain separate tracks.**
3. **Interfaces and agent workflows should meet a State Clarity Standard** before release or major workflow changes.

---

# 2. Findings

## Finding 1: Fresh-eyes failures are usually state failures, not visual failures

The most important fresh-eyes problems are not cosmetic. They are failures of context reconstruction.

A user or agent may fail because they cannot determine:

- What step they are on.
- What has already happened.
- What is expected next.
- Which values are defaults versus explicit choices.
- Whether an action is safe to retry.
- How to recover from interruption.
- Where the current machine-readable state lives.

Therefore, fresh-eyes review should prioritize **state clarity** over surface polish.

---

## Finding 2: Human and agent friction must be reviewed separately

Human users and agents fail in different ways.

Humans may struggle with:

- Ambiguous labels.
- Hidden controls.
- Unclear progress.
- Confusing defaults.
- Missing error or empty states.
- Destructive actions without confirmation.

Agents may struggle with:

- Lack of machine-readable state.
- Non-deterministic UI elements.
- Implicit assumptions about prior steps.
- Actions that are not idempotent.
- No explicit resume path after interruption.
- Conflation of user intent, system defaults, inferred state, and completed actions.

A generic “usability” review is insufficient because it tends to collapse these distinct failure modes into one vague assessment.

---

## Finding 3: Cadence converts fresh-eyes review from opinion into systemic defense

One-off reviews are useful but fragile. Without a cadence, fresh-eyes findings become anecdotal and do not accumulate into institutional knowledge.

A layered cadence creates recurring pressure to remove hidden assumptions before they normalize.

The recommended cadence is:

| Cadence | Scope | Purpose |
|---|---|---|
| **Per PR / per change** | Any UI, agent workflow, prompt, tool schema, or automation flow touched by the change | Catch state ambiguity and fresh-context failures early. |
| **Weekly** | Top 3 user journeys or agent workflows | Detect accumulated cognitive debt in active flows. |
| **Biweekly** | Zero-context agent audit against staging or a test environment | Simulate an agent with no memory of prior steps. |
| **Quarterly** | Adversarial red-team review | Stress-test hidden assumptions, interrupted sessions, stale state, and permission failures. |

A minimum viable version is sufficient to begin:

1. A PR checklist for UI/agent changes.
2. One weekly 30-minute human fresh-eyes review.
3. One biweekly zero-context agent audit.

---

## Finding 4: Agent workflows need explicit machine-readable state

Agent work is especially vulnerable when the current position in a workflow exists only in prose, logs, or implicit memory.

For agent-facing systems, the interface or workflow should expose enough state that a fresh agent instance can reconstruct its position without historical context.

This includes:

- Current step.
- Completed steps.
- Pending steps.
- Explicit defaults.
- Available actions.
- Constraints and permissions.
- Error conditions.
- Retry safety.
- Resume instructions.

If an agent cannot determine its current state from the visible or machine-readable context, the workflow is not fresh-eyes safe.

---

## Finding 5: Hidden assumptions become normalized behavior if not adversarially tested

Fresh-eyes review becomes adversarial when it deliberately assumes:

- The reviewer has never seen the system before.
- The agent has no memory of previous runs.
- The session was interrupted.
- State is stale.
- Permissions changed.
- A default value was silently applied.
- A prior step failed partially.
- The user or agent does not know implementation history.

Without this adversarial stance, teams often review only the happy path and miss the conditions where fresh context actually matters.

---

## Finding 6: State clarity should be a release gate, not a post-release cleanup task

Interfaces and agent workflows should not be considered complete until they satisfy a minimum standard of state clarity.

This is especially important for automation because unclear state can lead to repeated agent errors, unsafe retries, incorrect resumption, or silent normalization of bad behavior.

---

# 3. Core Recommendation

Adopt a **dual-track fresh-eyes review system** with the following permanent question:

> Can a human or agent understand, continue, and complete this workflow using only the current visible state, explicit instructions, and machine-readable context — without relying on prior memory, hidden assumptions, or implementation history?

This should be applied to:

- UI surfaces.
- Agent workflows.
- Prompts.
- Tool schemas.
- Automation runbooks.
- Operational dashboards.
- Approval flows.
- Error and recovery paths.
- Any workflow where a fresh human or agent instance may need to continue work.

---

# 4. Recommended Cadence

## Full cadence

| Cadence | Scope | Output |
|---|---|---|
| **Per PR / per change** | Any UI, prompt, tool schema, agent workflow, or automation flow touched by the change | Fresh-eyes checklist result and blocking/non-blocking findings. |
| **Weekly** | Top 3 active user journeys or agent workflows | Short review note identifying accumulated cognitive debt. |
| **Biweekly** | Zero-context agent audit against staging or test environment | Agent audit report with state reconstruction failures. |
| **Quarterly** | Adversarial red-team review | Stress-test findings around stale state, interruption, permissions, defaults, and partial failure. |

## Minimum viable cadence

If the full system is too heavy initially, adopt this baseline:

1. **PR checklist** for UI/agent changes.
2. **Weekly 30-minute human fresh-eyes review.**
3. **Biweekly zero-context agent audit.**

This minimum viable cadence should be treated as the default until evidence shows that more frequent or deeper review is needed.

---

# 5. Dual-Track Review Rubric

## Human Fresh-Eyes Track

Review as if you have never seen the interface before.

Check for:

- Ambiguous labels or actions.
- Hidden critical controls behind hover, scroll, or dynamic loading.
- Unclear progress or current step.
- Confusing defaults.
- Missing error, empty, success, and partial-failure states.
- Destructive actions without clear confirmation.
- Workflow steps that require prior knowledge to understand.
- Text that assumes implementation history.
- Controls whose meaning depends on invisible state.
- Recovery paths that are obvious only to people who built the system.

A human fresh-eyes review should ask:

> If I had never seen this before, could I confidently determine what is happening and what to do next?

---

## Agent Fresh-Eyes Track

Review as if the agent has no memory of previous runs.

Check for:

- Can the agent determine what step it is on?
- Can it infer what has already happened?
- Are defaults explicitly labeled, not silently assumed?
- Are actions idempotent or safely retryable?
- Are dynamic UI elements deterministic enough to act on?
- Is there a machine-readable state representation?
- Can the agent resume after interruption without historical logs?
- Does the interface distinguish between user intent, system default, inferred state, and completed action?
- Are error states explicit enough for the agent to choose a safe next action?
- Are permissions and constraints visible in the current context?

An agent fresh-eyes review should ask:

> If this agent instance started from zero memory, could it reconstruct its position and continue safely using only the current state?

---

# 6. State Clarity Standard

Every core flow in `hngh/hngh-automation` should pass this standard before release or major workflow changes.

## Required properties

1. **Current step is visible**
   - The user or agent can tell where they are in the workflow.

2. **Progress is explicit**
   - Breadcrumbs, step indicators, status labels, or equivalent machine-readable state exist.

3. **Defaults are labeled as defaults**
   - Defaults must not be treated as explicit user intent.

4. **No critical action depends on hover-only or unstable UI**
   - Critical actions should be reachable without transient states.

5. **Loading, error, empty, success, and partial-failure states are explicit**
   - The system should not leave the current condition ambiguous.

6. **Machine-readable state exists for agent-facing workflows**
   - Agents should be able to inspect current step, completed actions, pending actions, constraints, and available next actions.

7. **Actions are idempotent or safely retryable**
   - Retrying an action should not silently duplicate work or corrupt state unless the system explicitly prevents it.

8. **Interruption recovery is possible**
   - A fresh human or agent instance should be able to resume without relying on private memory or historical logs.

9. **User intent, system defaults, inferred state, and completed actions are distinguishable**
   - The interface or workflow state should not conflate what the user chose with what the system assumed.

10. **Error conditions expose a safe next action**
    - Errors should not only report failure; they should clarify what can be done next.

---

# 7. Concrete Recommendations for `hngh/hngh-automation`

## Recommendation 1: Add a fresh-eyes checklist to PRs touching UI or agent workflows

Any change affecting user-facing or agent-facing state should include a brief fresh-eyes review.

Minimum checklist:

- Is the current step visible?
- Are defaults explicit?
- Can a fresh human understand what happened?
- Can a fresh agent reconstruct its position?
- Are error, empty, loading, and partial-failure states handled?
- Are critical actions reachable without hover-only or unstable UI?
- Are destructive actions clearly confirmed?
- Is there machine-readable state for agent workflows?
- Can the workflow resume after interruption?

This checklist should be lightweight enough to run per change.

---

## Recommendation 2: Run a weekly human fresh-eyes review

Select the top 3 active user journeys or agent workflows each week.

Review them as if seeing them for the first time.

The output should be short:

- What is confusing?
- What assumes prior knowledge?
- What state is hidden?
- What action is unclear?
- What should be fixed before it becomes normalized?

This review does not need to be exhaustive. Its purpose is to prevent accumulated cognitive debt.

---

## Recommendation 3: Run a biweekly zero-context agent audit

Simulate an agent with no memory of prior steps.

The audit should use only:

- Current visible state.
- Explicit instructions.
- Machine-readable context.
- Available tools or actions.
- Current permissions and constraints.

The audit should answer:

- Can the agent determine its current step?
- Can it identify what has already happened?
- Can it determine what is safe to do next?
- Does it need historical logs to continue?
- Are defaults explicit enough?
- Are actions retry-safe?
- Would interruption cause confusion or unsafe behavior?

This audit should be treated as a first-class quality gate for agent workflows.
