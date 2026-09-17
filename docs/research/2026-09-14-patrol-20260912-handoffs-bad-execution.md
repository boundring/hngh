# patrol: surface handoffs filed bad-execution on two consecutive runs -- why does it keep failing and which guardrail closes it?

Status: crystallized 2026-09-14 from research line `patrol-20260912-handoffs-bad-execution`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-patrol-20260912-handoffs-bad-execution.md.

## Final Structured Summary for Research Line: Patrol - Surface Handoffs Filed Bad-Execution on Two Consecutive Runs

### Findings

1. **Budget/Guardrail Interaction**: The issue of bad-execution filings on two consecutive runs is not a one-off flake but a result of budget exhaustion. Bad executions consume session budget, which in turn prevents discretionary plan selection. A shared verdict rule can cause two surfaces to fail under the same stale or drifted rule.
2. **Guardrail**: The **consecutive bad-execution demotion/cancellation guardrail** should be triggered after two consecutive bad-execution filings on the same surface. This guardrail should stop further automatic handoff attempts unless an explicit new verdict-rule version, budget reset, or human-approved exception is introduced.

### Recommendations

1. **Make Two Consecutive Bad-Execution Filings Terminal for a Surface Handoff**:
   - If the same surface files bad-execution on run N and run N+1, do not auto-retry the same surface. Demote or cancel the handoff and close the patrol line unless the failure mode is explicitly reclassified.

2. **Treat Bad-Execution Burn as First-Class State**:
   - Every bad execution should decrement the relevant session budget. If discretionary plan selection would be exhausted, fail fast with a structured reason such as `bad-execution-burn-exhausted` instead of attempting another handoff.

3. **Bind Each Surface to an Explicit Verdict-Rule Version**:
   - Do not allow one shared verdict rule to silently serve two surfaces. Each handoff should record which verdict-rule version produced the result. If drift is detected, fail the handoff and require an explicit rebind or human review.

4. **Treat Blocked Apply-Patch Edits as Non-Success**:
   - If a guardrail blocks patch application, the handoff must not be marked completed. It should either produce an approved no-op/rollback, escalate to a human, or close under the bad-execution rule.

5. **Emit One Auditable Close-Out Event When the Guardrail Fires**:
   - The event should include:
     - Surface ID
     - Run IDs
     - `bad_execution_count = 2`
     - Budget before and after
     - Guardrail ID: consecutive bad-execution demotion/cancellation
     - Verdict-rule version
     - Action: `closed`, `demoted`, or `cancelled`

6. **Do Not Close the Line on a Single Bad Execution**:
   - One failure is diagnostic. Two consecutive failures on the same surface are the closing condition, unless the second failure uses a materially different verdict rule or budget state.

### Guardrail That Closes It

The closing guardrail is the **consecutive bad-execution demotion/cancellation guardrail**, referenced in prior material as `[[sources/outcome-demotion-at-two-consecutive-failures]]`. It should fire after two consecutive bad-execution filings on the same surface and stop further automatic handoff attempts.

### Verification Limits

- I cannot verify the prior beat’s candidate log, trace, guardrail-config, session-budget, or plan-selection paths as existing files.
- I cannot verify the upstream Hngh Analytics live README observation from this transition; treat it as an external lead only.
- The only concrete path cited below is the provided kernel repository root: `~/Projects/etc/hngh`.

### References

- [[concepts/roguelike-discipline]]: Roguelike Discipline in Agent Execution
- [[sources/outcome-demotion-at-two-consecutive-failures]]: Consecutive bad-execution cancellation
- [[sources/session-budget-burn-prevents-discretionary-plan-selection]]: Bad-execution burn

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
