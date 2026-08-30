# log organization/navigation/presentation patterns for the logs overhaul

Status: crystallized 2026-08-28 from research line `logs-known-good-patterns`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-logs-known-good-patterns.md.

# Final structured summary — log organization/navigation/presentation patterns for the logs overhaul

**Research line:** Log organization/navigation/presentation patterns for the logs overhaul

**Lifecycle state:** contracting → **crystallized / lasting record**

**Target:** `hngh/hngh-automation`

---

## Executive stance

Logs in `hngh/hngh-automation` should be treated as **structured, addressable, task-modeled telemetry**, not as a single flat chronological text stream.

The log experience should first answer:

> **“What failed, where did it fail, and why is this relevant now?”**

Then it should preserve strong paths for:

1. **Triage** — find the failure quickly.
2. **Audit** — reconstruct who did what to what, when.
3. **Debugging** — inspect chronological and contextual detail around a run, request, job, step, user, or resource.

The UI may transform logs into summaries, groups, views, and filters, but the underlying raw log store must remain **immutable, exportable, and sufficient for reconstruction**.

---

# Findings

## 1. Automation logs are event records, not just text lines

Logs in an automation system should be modeled as discrete events tied to meaningful entities:

- run
- workflow
- job
- step
- request / trace
- user / actor
- resource
- environment
- artifact
- ticket
- deployment

**Implication:** The log UI should not primarily depend on line numbers, file offsets, or raw text positions. It should anchor navigation around stable identifiers and semantic entities.

---

## 2. The dominant user task is triage, not reading logs chronologically

For automation operators, the most valuable question is usually:

> “Which runs failed, which steps failed, and what error caused it?”

A default chronological view is useful, but it is not the best primary experience for automation operations.

**Implication:** The default log view should be a **triage view**, surfacing failed runs, failed steps, errors, warnings, and recent failures first.

---

## 3. Chronology is necessary but insufficient

Chronological order is important for debugging and audit reconstruction, but it does not by itself explain automation state.

A user debugging an automation run needs to understand:

- which run they are in
- which job failed
- which step produced the error
- what request or trace correlates with that step
- what actor triggered the run
- what resource was affected
- whether a recent deploy or config change is relevant

**Implication:** Chronology should exist as one view, but not be the only organizing principle.

---

## 4. Audit and debugging have different information needs

Audit asks:

> “Who did what to what, when?”

Debugging asks:

> “What happened step by step around this failure or request?”

These are related but distinct tasks.

**Implication:** The log system should support at least three primary views:

1. **Triage**
2. **Audit**
3. **Debug**

Each view can share the same underlying structured data, but present it differently.

---

## 5. Semantic navigation is more useful than positional navigation

Users should be able to jump to meaningful landmarks such as:

- failed step
- first error in a run
- next error
- previous error
- request ID
- user action
- resource change
- deploy marker
- artifact reference
- ticket reference

**Implication:** Navigation should be semantic. Line numbers and scroll positions are secondary anchors, not primary ones.

---

## 6. Grouping should be task-driven

For `hngh/hngh-automation`, the most natural default grouping is automation-centric:

> **run → job → step**

Other useful lenses include:

- chronological
- actor-centric
- resource-centric
- request/trace-centric
- event-centric
- error-centric

**Implication:** The default view should depend on the user’s task. For automation operators, the default should be run/job/step triage. For auditors, the default may be actor/action/resource/time. For engineers debugging a request, the default may be trace/request chronological reconstruction.

---

## 7. Presentation must scale to large logs and long runs

Automation logs can become very large, especially when including:

- step output
- payloads
- retries
- nested job execution
- verbose debug output
- artifact references
- request traces

Rendering everything at once will degrade usability and performance.

**Implication:** The UI should use progressive disclosure, virtualized lists, lazy payload loading, expand-on-demand details, tail mode, and pagination or incremental loading.

---

## 8. Correlation identifiers are the connective tissue of the log experience

Without stable correlation fields, the log UI becomes brittle and hard to navigate.

Key correlation identifiers include:

- `event_id`
- `run_id`
- `workflow_id`
- `job_id`
- `step_id`
- `request_id`
- `trace_id`
- `actor` / `user_id`
- `resource_id`
- `environment`
- `error_code`

**Implication:** Every log event should expose enough identifiers to link it to related runs, jobs, steps, traces, users, resources, artifacts, deployments, and tickets.

---

## 9. Search,
