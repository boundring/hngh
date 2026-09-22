# Is the `outcome-demotion-at-two-consecutive-failures` guardrail explicitly wired to count `harvest-stale` events as "bad executions," and if so, why did it not trigger closure after two consecutive runs?

Status: crystallized 2026-09-22 from research line `fail-20260922-Is-the-outcome-demotion-at-two-consecuti`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260922-Is-the-outcome-demotion-at-two-consecuti.md.

# Research Line: `outcome-demotion-at-two-consecutive-failures` × `harvest-stale` Classification

## State Transition: Expanding → Contracted (Final)

**Line:** Is the `outcome-demotion-at-two-consecutive-failures` guardrail explicitly wired to count `harvest-stale` events as "bad executions," and if so, why did it not trigger closure after two consecutive runs?
**Action:** Crystallize final structured summary — findings, recommendations, and open threads.

## Executive Summary

The available prior art **does not confirm** that `harvest-stale` is explicitly wired to the `outcome-demotion-at-two-consecutive-failures` guardrail as a "bad execution" capable of triggering closure. The naming conventions and source nodes suggest a distinction between "hard failures" (which trigger demotion/closure) and "bad executions" (which burn session budget), but the specific classification of `harvest-stale` remains unverified in the provided vault pointers. The non-trigger after two consecutive runs is likely attributable to one of three causes: (1) `harvest-stale` is not classified as a "failure" for the demotion counter, (2) the counter reset semantics intervened, or (3) the upstream bug filed on 2026-08-25. Without direct access to the kernel source code defining the event classification map, this line cannot be resolved definitively from the vault alone.

## Findings

1. **No Explicit Wiring Confirmed:** The prior art does not contain a definitive mapping showing `harvest-stale` as an input to the `outcome-demotion-at-two-consecutive-failures` guardrail. The source node `[[sources/outcome-demotion-at-two-consecutive-failures]]` describes "Consecutive bad-execution cancellation" but does not enumerate which specific event types constitute a "bad execution" for closure purposes.
2. **Two-Tier System Hypothesis:** The co-occurrence of `[[sources/session-budget-burn-prevents-discretionary-plan-selection]]` and the demotion guardrail suggests a two-tier system:
   - **Tier 1 (Budget Burn):** Events like `harvest-stale` may only burn session budget, preventing discretionary plan selection but not triggering line closure.
   - **Tier 2 (Closure/Demotion):** Hard failures trigger the consecutive-failure counter and eventual closure.
   If `harvest-stale` is Tier 1, it will never trigger closure, explaining the non-trigger.
3. **Upstream Bug Signal:** The observation node `[[sources/obs-2026-08-25-guardrail-bug-filed-upstream-hngh-analytics-live-readme-curr]]` indicates a known discrepancy between documented behavior (analytics-live README) and implementation. This is the strongest prior-art signal that the wiring may be broken or misconfigured.
4. **Counter Reset Semantics Unverified:** The guardrail name specifies "consecutive" failures. If the counter resets on any non-failure event (e.g., a successful run, lifecycle state transition, or session reset), two `harvest-stale` events separated by even one intervening event will not trigger closure.

## Recommendations

1. **Verify Event Classification in Kernel Source**
   - **Action:** Inspect the hngh kernel repository (`[redacted path] to locate the event classification map or guardrail wiring logic.
   - **Specific Target:** Search for the strings `outcome-demotion-at-two-consecutive-failures` and `harvest-stale` within the kernel source. Determine if `harvest-stale` is tagged with a severity level that increments the consecutive-failure counter.
   - **Rationale:** The prior art suggests a two-tier system (hard failures vs. bad executions). If `harvest-stale` is only a "bad execution" and not a "hard failure," it will burn budget but not trigger demotion. This is the most likely explanation for the non-trigger.

2. **Audit Counter Reset Semantics**
   - **Action:** Review the state machine logic governing the consecutive-failure counter in `[redacted path]
   - **Specific Target:** Check if any intermediate event (e.g., a successful run, a lifecycle state transition, or a session reset) clears the counter between the two `harvest-stale` events.
   - **Rationale:** The guardrail name specifies "consecutive" failures. If the counter resets on any non-failure event, two `harvest-stale` events separated by even one successful run will not trigger closure. Verify the exact reset conditions in the kernel code.

3. **Cross-Reference Upstream Bug Filing**
   - **Action:** Examine the upstream bug filed on 2026-08-25 (referenced in `[[sources/obs-2026-08-25-guardrail-bug-filed-upstream-hngh-analytics-live-readme-curr]]`).
   - **Specific Target:** Locate the bug report in the hngh repository or associated issue tracker. Review the "analytics-live" README mentioned in the obs node to confirm the expected behavior for `harvest-stale` events.
   - **Rationale:** The obs node indicates a known discrepancy between documented behavior (README) and implementation. This is the strongest prior-art signal that the wiring may be broken or misconfigured.

4. **Instrument Lifecycle State Transitions**
   - **Action:** Add logging to track the lifecycle state of the research line during the two consecutive runs.
   - **Specific Target:** Verify if the line was in an active/running state when the guardrail should have armed. Some guardrails only activate after a transition from `planned` to `expanding` or similar states.
   - **Rationale:** If the line was not in the correct lifecycle state, the guardrail may not have been armed at all.

## Open Threads

1. **Kernel Source Verification:** The definitive answer requires inspecting `[redacted path] to locate the event classification map and counter reset logic. This is outside the scope of the vault pointers provided.
2. **Upstream Bug Resolution Status:** The bug filed on 2026-08-25 may have been resolved or reclassified. Checking the current status of this bug in the hngh repository would clarify if the wiring was fixed after the observation.
3. **Lifecycle State Interaction:** The interaction between lifecycle states (e.g., `contracting`, `expanding`) and guardrail arming is not fully documented in the prior art. Further investigation into how lifecycle transitions affect guardrail activation is needed.

## References

- `[[sources/outcome-demotion-at-two-consecutive-failures]]`
- `[[sources/session-budget-burn-prevents-discretionary-plan-selection]]`
- `[[sources/obs-2026-08-25-guardrail-bug-filed-upstream-hngh-analytics-live-readme-curr]]`
- `[redacted path] (hngh kernel repository)
