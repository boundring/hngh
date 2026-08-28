# session-cost display formats

Status: crystallized 2026-08-28 from research line `session-cost-display`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-session-cost-display.md.

# Research Line Record: Session-Cost Display Formats

**Lifecycle:** `contracting` → final crystallization
**Target:** `hngh/hngh-automation`
**Status:** Closed for expansion; ready for implementation and validation
**Core conclusion:** Session cost display should not be treated primarily as a receipt or accounting surface. It should be treated as a **budget-control and confidence surface** for human operators and automated workflows.

---

## 1. Findings

### F1. Raw token counts are not the primary user-facing signal

Token counts, API call counts, model-specific units, and deep decimal currency values are useful for debugging, but they do not directly answer the operator’s question:

> “Is this run affordable, safe, and within budget?”

The primary display should be money-based, budget-aware, and action-oriented.

### F2. Cost estimates must be ranges, not single numbers

Because model usage, context length, retries, tool calls, and workflow complexity can vary, a single estimated cost is misleading. The system should show:

```text
Estimated cost: $0.80–$1.20
```

A range communicates uncertainty without requiring the user to infer it.

### F3. Cost display needs three distinct states

The useful lifecycle for cost visibility is:

1. **Preflight / before run**
2. **During run**
3. **After run**

Each state answers a different question:

| State | Question answered |
|---|---|
| Preflight | “Should I start this?” |
| During run | “Is it still within expectations?” |
| After run | “What did it cost, and how close was the estimate?” |

### F4. Automation requires stronger guarantees than interactive chat

Interactive sessions can rely on a human watching the screen. Automated, queued, or background runs cannot assume continuous human attention. Therefore, automation must have:

- Projected total cost before execution
- A hard maximum allowed cost
- Live budget state
- Safe failure behavior when limits are approached or exceeded

### F5. Batch jobs need projected totals and caps

A batch job is not a single run. It should show:

```text
12 runs × est. $0.18–$0.35
Estimated total: $2.16–$4.20
Max allowed cost: $5.00
Daily budget left: $14.20
```

Batch jobs should not start without a maximum cost ceiling.

### F6. Overruns must be visible, logged, and operationally meaningful

If a run exceeds its estimate or cap, the system should not silently continue. It should produce:

- A user-visible warning or alert
- A structured log entry
- A post-run delta against the estimate
- An operational dashboard signal if relevant

### F7. Power-user detail should be secondary

Raw token counts, per-call costs, model-specific units, and four-decimal currency values are useful, but they should not dominate the primary UI. They belong in logs, debug panels, or explicit power-user views.

---

## 2. Recommendations

### R1. Ship one standard cost card for all sessions, runs, and batch jobs

Do not pursue multiple competing cost display experiments. Implement one shared cost display component with three states.

#### Preflight / Before Run

For a single session:

```text
Estimated cost: $0.80–$1.20
Daily budget left: $14.20 (71%)
Workflow: hngh-automation / code-review
```

For a batch job:

```text
12 runs × est. $0.18–$0.35
Estimated total: $2.16–$4.20
Max allowed cost: $5.00
Daily budget left: $14.20
```

#### During Run

```text
Cost so far: $0.35
Estimated final: $0.90–$1.10
Budget remaining: $13.85
Status: within estimate
```

#### After Run

```text
Final cost: $0.94
Estimate was: $0.90–$1.10
Delta vs estimate: +$0.04
Budget remaining: $13.26
```

### R2. Use money-first display rules

The primary UI should follow these rules:

- Show cost as a range when uncertain.
- Never show more than two decimal places in the primary UI.
- If cost is below one cent, show `<$0.01`, not `$0.0042`.
- Do not lead with tokens, API calls, or model-specific units.
- Keep raw token/cost data available in logs or a debug panel.
- Make budget state visible without opening settings or logs.

### R3. Tie cost display to execution gating

Cost visibility is not enough. For automation, cost display must be connected to decision gates.

#### Interactive Sessions

Behavior:

- Show estimate before start.
- Allow continuation if estimate is within normal budget.
- Warn if estimate exceeds a configurable threshold.
- Require confirmation if estimate exceeds a higher threshold.

Example:

```text
Estimated cost: $4.80–$6.20
This exceeds your normal workflow range.
Proceed?
```

#### Queued Batch Jobs

Before enqueueing, show:

```text
Projected batch cost: $2.16–$4.20
Max allowed cost: $5.00
Budget remaining after projected max: $10.00
```

Behavior:

- If projected maximum exceeds the configured cap, block or require explicit confirmation.
- No batch job should start without a maximum cost ceiling.

#### Unattended / Background Runs

Behavior:

- Require a hard `max_cost_usd` per run or per batch.
- If live cost approaches the cap, pause, fail safely, or notify depending on workflow policy.
- Log estimate versus final cost for every run.
- Overruns must produce an alert and a structured log entry.

### R4. Define minimum job metadata

Batch jobs and automated runs should expose at least:

```text
estimated_min_usd
estimated_max_usd
max_allowed_usd
final_cost_usd
delta_vs_estimate_usd
budget_remaining_usd
cost_status
```

Where `cost_status` can be one of:

```text
within_estimate
above_estimate
below_estimate
over_cap
paused_at_cap
failed_safely
completed_overrun_flagged
```

### R5. Make overruns operationally visible

Every overrun or near-overrun should produce a structured event containing:

- Run ID
- Workflow name
- Estimate range
- Final cost
- Cap
- Delta
- Budget remaining
- Action taken: `warned`, `paused`, `failed`, `completed_overrun_flagged`
- Timestamp

This makes cost behavior auditable and useful for dashboards.

---

## 3. Acceptance Criteria

A session-cost display implementation is complete when:

- Every interactive session shows a preflight estimate when possible.
- Every batch job shows projected total and maximum cap before execution.
- The primary UI never displays four-decimal currency values.
- Cost state is visible without opening settings or logs.
- Batch jobs expose `estimated_min_usd`, `estimated_max_usd`, and `max_allowed_usd`.
- Runs exceeding their cap are stopped, paused, flagged, or safely failed before completion.
- Budget overruns are visible in operational dashboards.
- Raw token/cost data remains available for debugging without polluting the primary UI.

---

## 4. Open Threads

These are not blockers to adopting the recommendation, but they should be resolved during implementation.

### O1. Estimate accuracy and calibration

The system needs a practical way to estimate cost ranges. Open questions:

- How should estimates account for context length?
- How should retries, tool calls, and multi-step workflows affect the range?
- Should estimates be based on historical run data?
- How often should estimate models be recalibrated?

### O2. Budget hierarchy

The system may need multiple budget levels:

- Per-run
- Per-batch
- Per-workflow
- Per-day
- Per-user or per-tenant

Open question: which budgets are authoritative, and how do they interact?

### O3. Cap enforcement policy

Different workflows may need different behavior when approaching a cap:

- Warn only
- Pause for confirmation
- Fail safely
- Notify operator
- Stop immediately

Open question: what is the default policy for `hngh/hngh-automation`?

### O4. Multi-model and multi-provider cost normalization

If runs can use multiple models or providers, costs must be normalized into a common currency view. Open questions:

- How to handle different pricing tiers?
- How to represent mixed-model runs?
- Should the UI show per-model breakdowns in debug mode only?

### O5. Partial-run accounting

If a run is cancelled, paused, or fails partway through, cost display should still be meaningful. Open questions:

- What does “final cost” mean for an incomplete run?
- Should partial runs show `partial_cost_usd`?
- How should estimate delta be calculated for interrupted runs?

### O6. UI placement and persistence

The cost card must be visible in the right contexts. Open questions:

- Where does it appear during long-running jobs?
- Does it persist across queue views, run detail pages, and dashboards?
- Is there a compact version for batch lists?

### O7. Evaluation metrics

To validate that this improves operator confidence, track:

- Overrun rate
- Time to detect budget risk
- Number of blocked or confirmed high-cost runs
- User trust / usability feedback
- Estimate error distribution
- Frequency of silent overruns before and after implementation

---

## 5. Final Position

The line should now be treated as **contracted**, not open-ended.

The durable recommendation is:

> Implement one standard cost card for `hngh/hngh-automation` that shows estimated cost range, live budget state, and post-run delta. Tie this display to execution gating so interactive sessions can warn or confirm, batch jobs require caps, and unattended runs fail safely when limits are exceeded. Raw token data remains available for debugging, but the primary user-facing surface is money, budget, and risk.
