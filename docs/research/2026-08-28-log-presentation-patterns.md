# log-presentation patterns

Status: crystallized 2026-08-28 from research line `log-presentation-patterns`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-log-presentation-patterns.md.

# Final contracted research line: log-presentation patterns

**Line:** log-presentation patterns
**Lifecycle:** contracting → crystallized
**Scope:** human-facing log presentation for operators, engineers, support staff, and auditors working with `hngh/hngh-automation`.
**Assumption:** `hngh/hngh-automation` produces operational logs from automation runs, jobs, workflows, API calls, data transformations, scheduled tasks, or similar execution paths.
**Evidence status:** crystallized from prior research material; implementation-specific validation still required against the actual codebase and log pipeline.

---

## Contracted thesis

For `hngh/hngh-automation`, logs should be presented as **correlated evidence slices**, not as raw chronological text.

The primary presentation unit is not a single log line. It is a **log slice**: a bounded group of related events around an automation run, job, step, entity, user, tenant, request, or failure window.

Raw logs remain important, but they should be the **final drill-down layer**, not the default view.

Presentation quality is constrained by log structure. If `hngh/hngh-automation` logs are mostly free text, no UI can fully compensate; it will only make missing structure more visible. Therefore, the line’s final position is:

> **Slice-first presentation, contract-driven logging.**
> The default human-facing surface should show bounded execution slices with status, impact, retries, dependencies, and next action. Raw chronological logs are a drill-down layer. Before investing heavily in UI polish, enforce a structured log contract with stable correlation identifiers and event taxonomy.

---

# Findings

## 1. Operators do not primarily need “more lines”; they need bounded evidence

A raw line such as:

```text
ERROR Payment failed
```

is weak because it does not answer the operator’s real questions:

- Which automation run failed?
- Which job or step failed?
- Did it retry?
- Was an external dependency involved?
- Which tenant, user, or entity was affected?
- What is the likely next action?

The useful unit is a slice such as:

> **Payment automation**, environment `prod`, run `run_12345`, job `job_67890`, step `payment_capture`, user `u_987`, between `10:02:11–10:02:14`:
> 3 related events, 1 error, payment provider timeout, retry count `2`, external call latency `1850ms`.

This slice is immediately more actionable than a raw chronological stream.

---

## 2. Automation logs are multi-event by nature

Automation systems usually produce sequences such as:

- run started
- step started
- validation passed/failed
- external API call started
- retry scheduled
- state changed
- dependency timed out
- job completed or failed

A single log line rarely captures the full failure. Presentation must therefore group events around execution context rather than treating each line as an independent artifact.

---

## 3. The default view should be slice-first, not stream-first

The primary human-facing surface should show:

- run health
- job status
- step failures
- entity impact
- retry behavior
- external dependency failures
- state transitions
- error summaries
- next likely action

Raw chronological logs should be available, but they should be a drill-down layer for engineers or auditors who need exact event-level detail.

---

## 4. Structured metadata is a prerequisite for good presentation

Presentation quality depends on whether logs can be reliably grouped and filtered.

If logs lack stable identifiers such as `run_id`, `job_id`, `step_id`, `request_id`, `tenant_id`, or `entity_id`, the system cannot confidently build slices.

Free-text logs may be parsed heuristically, but that is fragile. The durable recommendation is to make structured fields part of the logging contract.

---

## 5. Different roles need different slice views

### Operators

Need:

- What failed?
- Which run/job/step?
- Is it retrying?
- Is it likely transient or systemic?
- What should I do next?

### Engineers

Need:

- Exact event sequence
- dependency latency
- error codes
- stack traces
- state transitions
- raw logs

### Support staff

Need:

- Which user, tenant, or entity was affected?
- When did it happen?
- What automation action failed?
- Is there a customer-facing impact
