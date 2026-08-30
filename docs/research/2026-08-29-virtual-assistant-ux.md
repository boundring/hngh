# virtual assistant as companion surface: configuration, actions, guidance UX

Status: crystallized 2026-08-29 from research line `virtual-assistant-ux`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-virtual-assistant-ux.md.

# Research Line: Virtual Assistant as Companion Surface

**Configuration, Actions, Guidance UX**

**Line state:** Contracting → crystallized / lasting record

**Primary application target:** `hngh/hngh-automation`

**Contracted thesis:** The companion surface should not be a broad emotional assistant or generic smart-home persona. For `hngh-automation`, it should be a **low-latency, high-trust interaction layer** that reduces friction around automation by making configuration implicit but editable, actions transparent and interruptible, and guidance contextual rather than intrusive.

---

## 1. Executive Summary

This line is crystallized into three durable implementation patterns:

1. **Configuration should be inferred first, then explicitly overridable.**

   Avoid a setup wizard as the primary onboarding path. Instead, observe early behavior, form visible assumptions, and let the user correct them with minimal effort.

2. **Actions should expose intent before execution.**

   Multi-step automation must present a structured plan before side effects occur. The user should be able to confirm, edit, cancel, or partially proceed without losing control of the workflow.

3. **Guidance should be tiered by urgency, reversibility, and context.**

   Proactivity is useful only when anchored to system state, time, deadlines, or current activity. Low-priority guidance must not interrupt; high-priority guidance must be rare and clearly justified.

The lasting value of this line is not “make the assistant feel companion-like.” The operational goal is: **make automation feel predictable, inspectable, and safe enough that users trust it to act.**

---

## 2. Scope Lock

### In scope
- Configuration UX for a virtual assistant in an automation context.
- Action UX for single-step and multi-step automation.
- Guidance UX for proactive, contextual, and reactive assistance.
- Trust, latency, control, and friction considerations specific to `hngh/hngh-automation`.

### Out of scope
- General parasocial relationship theory.
- Broad consumer assistant market research.
- Long-term memory architecture.
- Multi-device orchestration.
- Emotional companionship design.
- Full product roadmap beyond the companion interaction layer.

This line is now contracted. Future expansion should only occur if new evidence invalidates one of the core patterns above.

---

## 3. Findings

### F1. Explicit configuration creates onboarding friction and delays useful behavior

**Finding:**

Traditional setup wizards force users to define preferences before the assistant becomes useful. In an automation context, this is especially costly because users must reason about future behavior before they have experienced the system.

**Implication:**

The companion surface should begin with reasonable inferred defaults rather than requiring explicit configuration.

**Confidence:** Medium-high as a design constraint for `hngh-automation`.

**Basis:** Prior beat identified setup friction and low adoption of explicit configuration; retained as a directional prior, not a validated benchmark.

---

### F2. Inference without visibility creates distrust

**Finding:**

If the assistant infers preferences silently, users may feel the system is opaque or unpredictable. Inference is useful only when the inferred state is visible and correctable.

**Implication:**

Configuration should be represented as a **“Current Assumptions”** surface, not hidden behind settings menus.

**Confidence:** High for trust-sensitive automation contexts.

---

### F3. Black-box multi-step automation erodes user control

**Finding:**

When an assistant executes multiple steps without exposing its plan, users cannot reason about what will happen next. This is especially dangerous when actions are irreversible, costly, or affect shared systems.

**Implication:**

Multi-step actions must be represented as explicit plans with inspectable steps, risk levels, and intervention points.

**Confidence:** High.

---

### F4. Users need to intervene at the step level, not only at the task level

**Finding:**

A binary “approve / reject” model is insufficient for multi-step automation. Users may want to approve most steps while removing or modifying one specific step.

**Implication:**

The action UX must support granular intervention: confirm all, edit a step, cancel a step, skip dependent steps, or abort entirely.

**Confidence:** High.

---

### F5. Proactive guidance is only valuable when it is contextually anchored

**Finding:**

Generic proactive messages feel noisy. Guidance becomes useful when tied to concrete anchors such as time, calendar events, system state, recent user activity, or pending automation.

**Implication:**

Guidance UX should be organized around temporal and environmental triggers, not random assistant chatter.

**Confidence:** High.

---

### F6. Proactivity must be tiered by urgency and reversibility

**Finding:**

Not all guidance deserves the same interruption level. A failed CI pipeline before a deploy is different from a suggestion to validate a schema, which is different from a low-priority summary.

**Implication:**

The companion surface needs a **Nudge Priority Matrix** that maps message type, urgency, reversibility, and user context to UI channel and interruption behavior.

**Confidence:** High.

---

### F7. Trust depends on auditability and recoverability

**Finding:**

Users are more likely to trust automation when they can see what the assistant assumed, what it planned, what it executed, and how to undo or correct it.

**Implication:**

The companion surface should expose assumptions, plans, approvals, outcomes, and rollback paths where possible.

**Confidence:** High for automation systems with side effects.

---

## 4. Contracted Recommendations

### R1. Configuration: Use “Editable Defaults via Inference”

**Recommendation:**

Do not begin `hngh-automation` with a full setup wizard. Instead, infer initial preferences from early interactions and expose them in a visible, editable assumptions panel.

#### Core behavior
The assistant should observe the first few meaningful interactions and form provisional assumptions such as:

- Preferred response length: concise vs. detailed.
- Confirmation style: confirm every action vs. auto-approve low-risk actions.
- Proactivity tolerance: interrupting alerts vs. ambient hints vs. passive summaries.
- Time-of-day preferences for proactive nudges.
- Risk tolerance for automation involving shared systems, external notifications, or irreversible operations.

#### Required UI surface
A collapsible **“Current Assumptions”** panel should display inferred settings in plain language.

Example:

> **Current assumptions**

> - I assume you prefer concise summaries.

> - I assume you want confirmation before high-risk actions.

> - I assume low-risk local changes can be auto-approved.

> - I will not interrupt you during focused work unless something fails.

>

> [Change] [Reset to defaults]

#### Design rules
- Every inferred setting must be visible.
- Every inferred setting must have a one-click override.
- Overrides should persist and take precedence over future inference.
- The system should show why an assumption exists when possible: “I inferred this because you confirmed three low-risk actions without editing.”
- Users should be able to reset assumptions without losing explicit preferences.

#### Why this matters for `hngh/hngh-automation`
This reduces cold-start friction while preserving user control. The assistant feels tuned immediately, but the tuning is inspectable rather than magical.

---

### R2. Actions: Use “Plan-Preview-Execute” for Multi-Step Automation

**Recommendation:**

Any multi-step automation should generate a structured plan object before executing side effects. The plan should be visible, editable, and interruptible.

#### Core behavior
Before executing a task such as:

> “Update the database, notify the team, and log the
