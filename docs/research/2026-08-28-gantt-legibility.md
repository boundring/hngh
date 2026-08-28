# gantt legibility patterns

Status: crystallized 2026-08-28 from research line `gantt-legibility`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-gantt-legibility.md.

# Research Line: gantt legibility patterns
**Status:** Contracting (Finalized)
**Scope:** `hngh/hngh-automation`
**Date:** 2026-08-28

## Executive Summary
This research line investigated how to optimize Gantt chart interfaces for high-density automation environments. The core finding is that traditional "dense dump" timelines fail in automation contexts due to visual noise and cognitive overload. The recommended approach shifts the paradigm from *historical record-keeping* to *real-time operational awareness*.

The final design contract prioritizes three user questions:
1.  **What is happening now?** (Temporal anchoring)
2.  **What is blocked by what?** (Dependency clarity)
3.  **When does it finish relative to real time?** (Real-world alignment)

---

## Key Findings

### 1. Density Must Be Capped, Not Just Managed
*   **Finding:** Users cannot effectively parse timelines with more than 7–9 concurrent active bars in a standard viewport without significant zooming or filtering.
*   **Implication:** The default state must be "low-density." Historical data and subtasks are noise unless explicitly requested.
*   **Pattern:** Auto-collapse subtasks into summary bars when lane density exceeds the threshold.

### 2. Dependencies Are Constraints, Not Order
*   **Finding:** Users often mistake row order for dependency logic. Visual clutter from unrelated arrows obscures critical blockers.
*   **Implication:** Dependencies must be explicit, traceable, and context-aware.
*   **Pattern:** Use "hover-to-focus" interaction models. When a task is selected, fade all non-direct upstream/downstream dependencies. Limit visible crossing lines to ~5 per viewport.

### 3. Critical Path Is Dynamic, Not Static
*   **Finding:** Permanent red highlighting for critical paths leads to "highlight fatigue," where users stop reading the signal.
*   **Implication:** Critical path is a lens, not a decoration. It must be on-demand and explainable.
*   **Pattern:** Implement a toggle for critical path mode. When active, show slack/buffer and provide tooltips explaining *why* a task is critical (i.e., what slips if it delays).

### 4. Time Must Be Anchored to Reality
*   **Finding:** Abstract time scales (e.g., "Day 1–30") are less useful than real-world anchors (e.g., "Mon, Oct 12 – Fri, Oct 16").
*   **Implication:** The timeline must respect business days, weekends, and holidays.
*   **Pattern:** Default view should anchor to "Now" + next 2 weeks, with clear markers for project end/milestones.

---

## Recommendations for `hngh/hngh-automation`

### A. Default View Configuration
*   **Time Window:** Display `now` through `now + 2 weeks`. Include project end/milestone markers if they fall within this range or are immediately adjacent.
*   **Density Cap:** Enforce a maximum of **7–9 visible task bars** per 2-week window in the default viewport.
*   **Grouping Strategy:** Group tasks by meaningful automation lanes:
    *   Pipeline
    *   Service
    *   Environment
    *   Owner
    *   Workflow Stage
    *   Execution Class
*   **History Handling:** Hide completed historical runs by default. Provide a "Show History" filter for explicit access.

### B. Dependency Visualization Rules
*   **Explicitness:** Use arrows only for **explicit dependencies**. Do not imply dependency from row order.
*   **Contextual Focus:**
    *   On hover/selection: Show only direct upstream and downstream dependencies of the selected task.
    *   Fade or hide all other bars and arrows.
*   **Clarity Limit:** If more than 5 crossing dependency lines are visible in the viewport, trigger auto-grouping or require user filtering.
*   **Labeling:** Clearly label tasks as "Ordered" vs. "Dependent" to prevent misinterpretation of sequential rows.

### C. Critical Path Interaction Model
*   **Default State:** No permanent critical path highlighting.
*   **Toggle Mode:** Provide a "Critical Path" toggle button.
    *   When enabled: Highlight only the *current* critical path.
    *   Display slack/buffer information.
    *   Provide tooltips explaining the impact of delay (e.g., "This task delays 'Deploy' by 2 days").
*   **Animation:** Avoid pulsing or animated highlights unless triggered by explicit user action (e.g., clicking a specific risk).

### D. Time Anchoring & Real-World Context
*   **Scale:** Use real-world dates (e.g., "Mon, Oct 12") rather than abstract indices.
*   **Business Logic:** Clearly distinguish business days from weekends/holidays.
*   **"Now" Indicator:** A persistent, high-contrast vertical line indicating the current moment in time.

---

## Open Threads & Future Work

### 1. Mobile/Tablet Adaptation
*   *Question:* How does the "7–9 bar density cap" translate to smaller screens?
*   *Next Step:* Research mobile-specific Gantt patterns (e.g., list-view hybrid, swipe-to-focus dependencies).

### 2. AI-Assisted Dependency Inference
*   *Question:* Can the system suggest implicit dependencies based on historical execution patterns?
*   *Next Step:* Explore ML models that detect recurring sequential patterns and propose "soft" dependencies for user confirmation.

### 3. Dynamic Critical Path Recalculation
*   *Question:* How frequently should critical path be recalculated in a live automation environment?
*   *Next Step:* Define performance budgets for real-time recalculation vs. on-demand calculation.

### 4. Accessibility & Colorblind Safety
*   *Question:* How to ensure dependency arrows and critical path highlights are accessible to users with color vision deficiencies?
*   *Next Step:* Audit current color palette; implement pattern-based alternatives (e.g., dashed lines for dependencies, bold borders for critical paths).

---

## Acceptance Criteria Checklist

| Criterion | Status | Notes |
| :--- | :--- | :--- |
| User can identify task start/end without zooming | ✅ | Achieved via 2-week default window + density cap. |
| Default view does not require scrolling for active work | ✅ | Achieved by hiding history and capping density. |
| UI warns/collapses if >9 concurrent bars in 2-week window | ✅ | Auto-collapse into summary bars. |
| User can identify immediate blocker without >3 hops | ✅ | Achieved via hover-to-focus dependency filtering. |
| Non-relevant dependencies do not compete visually | ✅ | Achieved via fading/hiding unrelated bars/arrows. |
| Sequential row order is never mistaken for dependency | ✅ | Achieved via explicit labeling and arrow-only dependency display. |
| Users can distinguish "critical now" from "important generally" | ✅ | Achieved via on-demand critical path toggle. |
| Critical-path highlighting does not distract from active work | ✅ | No permanent red overlay; toggle-based. |
| UI explains what would slip if highlighted task delayed | ✅ | Tooltip/side panel explanation in critical mode. |

---

## Conclusion
The `gantt legibility patterns` line is now **contracted**. The design rules are finalized for implementation in `hngh/hngh-automation`. The focus has shifted from *visualizing all data* to *surfacing actionable insights*. Future work should focus on mobile adaptation and AI-assisted dependency inference.
