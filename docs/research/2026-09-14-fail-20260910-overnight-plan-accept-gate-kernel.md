# Why did plan acceptance fail with kernel make test rc=2 for identity overnight:plan-accept-gate:kernel, and is the blocker still open or already resolved?

Status: crystallized 2026-09-14 from research line `fail-20260910-overnight-plan-accept-gate-kernel`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260910-overnight-plan-accept-gate-kernel.md.

# Research Line: Plan Acceptance Failure (rc=2) — Final Structured Summary

**Line ID:** `identity overnight:plan-accept-gate:kernel`
**Status:** Contracted / Closed for this transition
**Date:** 2026-09-14

## Executive Summary

The research line investigated why the kernel plan acceptance gate failed with `make test rc=2` and whether the underlying blocker remains open. Due to lack of read access to the automation repository (`/home/bricker/Projects/etc/hngh`) and the specific gate implementation in this transition, the exact root cause (e.g., specific failing recipe, environment drift, or harness error) **cannot be definitively identified** from static analysis alone.

However, the investigation established that the failure mode is primarily an **observability gap** in the gate layer: the gate records only the exit code (`rc=2`) without capturing diagnostic context (stderr, failing recipe line). This prevents automatic triage and leads to ambiguous plan rejections. The blocker is considered **technically open** until a fresh gate run with enhanced logging is performed to distinguish between kernel test failures, harness errors, and environment drift.

## Findings

1.  **Exit Code Semantics:** `rc=2` in GNU make indicates a fatal error (e.g., syntax error, missing prerequisite, or recipe failure). It does not inherently identify *which* component failed. This is general GNU make knowledge; specific mapping to hngh kernel targets is unverified without repo access.
2.  **Observability Failure:** The gate currently treats `rc=2` as a binary rejection signal. It does not capture:
    -   The last failing recipe line.
    -   Stderr tail output.
    -   Whether the failure was due to test logic, build environment, or harness misconfiguration.
3.  **Ambiguity in Rejection Classes:** The gate conflates three distinct failure classes:
    -   (a) Kernel tests red (actual code/test failures).
    -   (b) Harness failure (make invocation errors, wrong CWD, missing tools).
    -   (c) Environment failure (idle host drift, unset env vars, timeouts).
    Current evidence suggests hngh has a recurring pattern of conflating these classes, leading to silent discarding of sound plans due to non-kernel-related failures.
4.  **Resolution Status:** The blocker is **not confirmed resolved**. Any claim of resolution without a fresh gate run on the current tree would be speculative. The line remains open pending execution of recommended verification steps.

## Recommendations

### R1: Enhance Gate Logging
-   **Action:** Modify the gate to capture `make test` output to a per-run log artifact.
-   **Detail:** On non-zero exit, extract and store the last failing recipe line and stderr tail in the gate verdict record.
-   **Rationale:** Prevents future manual triage for `rc=2` incidents.
-   **Implementation Note:** Locate gate logic by grepping the automation repo for `plan-accept-gate`. *Unverified: Specific file paths not cited due to lack of repo access.*

### R2: Classify Gate Rejections
-   **Action:** Update the gate's verdict schema to distinguish three failure classes:
    1.  **Kernel Tests Red:** Recipe failed inside the test suite.
    2.  **Harness Failure:** Make could not start, wrong working directory, missing tool.
    3.  **Environment Failure:** Idle overnight host drift, unset env, timeout/kill surfaced as `rc=2`.
-   **Rationale:** Reduces plan starvation by preventing sound plans from being vetoed due to harness/environment issues. Connects to prior art on backlog disposition sweeps reducing accepted plans by half; ambiguous gates compound this effect. *Directional inference, not measured.*

### R3: Distinguish Make Exit Codes and Log Timeouts
-   **Action:** Implement logic in the gate to differentiate between `rc=1` (with `-q`) and `rc=2` (fatal error).
-   **Detail:** Log timeouts separately from make exit codes. A timeout should not be conflated with a make fatal error.
-   **Rationale:** Improves diagnostic precision and prevents misclassification of environment-induced failures as kernel test failures.

## Open Threads

1.  **Verification Execution:** The next transition with shell access must execute the gate on the current tree to determine if the blocker is resolved. This requires:
    -   Running `make test` in the kernel repository.
    -   Capturing full output and exit code.
    -   Comparing against the enhanced logging schema (R1).
2.  **Repo Access:** Read access to `/home/bricker/Projects/etc/hngh` is required to verify:
    -   The specific Makefile targets involved in `make test`.
    -   The gate implementation details and current logging behavior.
3.  **Environment Drift Analysis:** Further investigation into idle overnight host drift patterns may be warranted if R2 classification reveals a high frequency of environment failures.

## References

-   **GNU make documentation:** General knowledge regarding exit code semantics (`rc=1`, `rc=2`). *External source, not verified against hngh repo.*
-   **Prior Art Pointers (llm-wiki vault):**
    -   `[[entities/hngh]]` Hngh Agent Kernel
    -   `[[sources/SRC-2026-08-24-030]]` Case Study: Overnight Multi-Agent Sprint (2026-08-24)
    -   `[[concepts/context-distillation]]` context distillation
    -   `[[sources/SRC-2026-08-18-006]]` History Collector - Agent Memory Distillation Pipeline
    -   `[[sources/backlog-disposition-sweep-reduces-accepted-plans-by-half]]` Evidence-gated disposition sweep reduces accepted plans by half
    -   `[[sources/hngh-2026-09-09-stall-lessons]]` Hngh stall lessons: model burn, acceptance parsing, orp

*Note: No specific file paths from the hngh kernel repository are cited in this summary due to lack of verified read access in this transition. All claims regarding repo-specific behavior are flagged as unverified pending execution.*
