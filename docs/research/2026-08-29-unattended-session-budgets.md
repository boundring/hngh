# budget optimization for unattended model sessions: caps, quotas, cost telemetry

Status: crystallized 2026-08-29 from research line `unattended-session-budgets`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-unattended-session-budgets.md.

# Final Research Line Record

**Line:** Budget optimization for unattended model sessions: caps, quotas, cost telemetry

**Lifecycle state:** Contracting → crystallized

**Applicable to:** `hngh/hngh-automation`

**Disposition:** This line is now a durable operational principle, not an open exploratory research thread. Further work should be scoped as implementation, instrumentation, or exception handling, not as re-opening the core thesis.

---

## 1. Contracted Thesis

Every unattended model session must be treated as a **bounded, observable, killable job**, not as an open-ended agent run.

The primary control surface is not prompt engineering, model selection, or self-reported confidence. The primary control surface is:

1. An explicit budget envelope attached to the job.
2. Enforcement outside the agent loop.
3. Telemetry that captures token burn, compute burn, wall-clock time, tool activity, and cost attribution.
4. Hierarchical quotas that are simple enough to operate without a full predictive system.

The goal is not to make every run cheap. The goal is to ensure that no unattended model session can silently consume excessive time, tokens, GPU memory, wall-clock time, tool-call cycles, or human attention without being stopped, logged, and attributed.

---

## 2. Scope

This line applies to:

- CI-triggered model sessions
- Scheduled automation runs
- Background agent jobs
- Long-running research or debugging sessions
- Multi-step tool-using model sessions
- Local/GPU model runs
- API-backed model runs
- Mixed local/API pipelines

It does **not** primarily concern:

- Prompt wording optimization
- Model size selection as a first-order control
- Agent confidence scoring
- Dynamic quota allocation based on predicted success
- Fine-grained cost forecasting, except as a later extension

---

## 3. Findings

### F1. Unattended model sessions are jobs, not prompts

A single prompt is insufficient to describe the risk surface of an unattended session. The relevant unit is the job:

```text
job = model + tools + environment + budget + timeout + telemetry + kill policy
```

If a session can run without a budget, it should be treated as unsafe by default.

---

### F2. Cost is multi-dimensional

Token count alone does not capture cost or risk. A session may burn:

- API tokens
- Local GPU time
- Wall-clock time
- Context/KV-cache memory
- Tool-call cycles
- Retry attempts
- Human review time
- Queue capacity
- Concurrency slots

A budget system that only tracks `max_tokens` will miss silent burn from long wall-clock runs, repeated tool calls, stuck loops, and GPU memory pressure.

---

### F3. The agent cannot be trusted to enforce its own budget

The model or agent may:

- Ignore budget instructions
- Hallucinate completion
- Get stuck in a loop
- Repeatedly call the same tool
- Misreport progress
- Escalate scope without permission
- Continue after failure conditions

Therefore, budget enforcement must live outside the agent loop. The agent may request work within a budget, but it must not be able to raise its own cap.

---

### F4. Budgets must be explicit and fail closed

A session should not start if required budget fields are missing.

If cost is unknown, the system should not silently assume zero cost or unlimited cost. It should require an explicit override or reject the job.

This prevents accidental unbounded execution caused by incomplete manifests, missing pricing metadata, or stale configuration.

---

### F5. Enforcement must be layered

No single layer is sufficient. The safest architecture uses multiple enforcement points:

| Layer | Responsibility |
|---|---|
| Job manifest | Declares budget envelope |
| Runner | Tracks wall time, steps, tool calls, retries |
| Gateway/proxy | Enforces token, request, and cost limits per model call |
| Watchdog | Detects no-progress, repeated actions, abnormal burn rate |
| CI/scheduler | Enforces global quotas, concurrency, daily limits |

The agent may be bounded by its own internal logic, but that is defense-in-depth only. The authoritative budget lives outside the agent.

---

### F6. Telemetry must exist even when a session is killed

A killed run is not a failed telemetry event. A killed run is the most important telemetry event.

If a session is terminated because it exceeded budget, hit no-progress, or produced abnormal burn, the system must still emit:

- Final token counts
- Final cost estimate
- Wall-clock duration
- Step count
- Tool-call count
- Kill reason
- Phase reached
- Budget remaining at kill time
- Attribution metadata

Without this, budget optimization becomes impossible because the worst runs are exactly the ones that disappear from the record.

---

### F7. Deterministic phase budgets are safer than confidence-based quotas

Using model-reported confidence to expand or contract budgets is risky as a first implementation. Confidence can be unreliable, miscalibrated, or gamed by hallucinated success states.

A better first system uses deterministic phase envelopes:

- Plan
- Explore
- Execute
- Verify
- Report

Each phase has conservative defaults. Dynamic allocation can be considered later, but only after deterministic budgets and telemetry are stable.

---

### F8. Killability is as important as cost optimization

A budget system that only warns is incomplete. The system must be able to stop a session when:

- Budget is exhausted
- Wall-clock limit is reached
- Step count is exceeded
- Tool-call count is exceeded
- Retry count is exceeded
- Context size exceeds safe limits
- No-progress condition persists
- Repeated identical actions are detected
- Burn rate becomes abnormal
- Telemetry heartbeat stops

A session that cannot be killed safely is not a bounded job.

---

### F9. Quotas should be hierarchical but simple

Quotas should exist at multiple levels:

1. Global / organization
2. Project
3. Runner
4. Job
5. Phase

However, the first implementation should avoid complex reallocation logic. The hierarchy should be a ceiling system, not an adaptive resource market.

Simple rule:

```text
child budget <= parent quota
parent exhaustion blocks new jobs
no implicit borrowing
explicit escalation only
```

---

### F10. Optimization comes after observability

The correct sequence is:

1. Make all sessions bounded.
2. Make all sessions observable.
3. Kill abnormal sessions safely.
4. Attribute cost accurately.
5. Then
