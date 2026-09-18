# patrol: surface feeds filed feed-stale on two consecutive runs -- why does it keep failing and which guardrail closes it?

Status: crystallized 2026-09-18 from research line `patrol-20260916-feeds-feed-stale`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-patrol-20260916-feeds-feed-stale.md.

# Research Line: Patrol `feed-stale` Recurrence & Guardrail Closure

**Line State:** Contracting (Final Structured Summary)  
**Repository Context:** `[redacted path] (hngh kernel)  
**Date:** 2026-09-18  

## Executive Summary
The recurring `feed-stale` failures on patrol surfaces are diagnosed as a **semantic mismatch between freshness verification and filesystem metadata**. The system relies on weak signals (mtime/timestamps) that do not correlate with actual content advancement, leading to false positives during idle periods or partial writes. The line is closed by identifying the **Two-Consecutive-Failure Demotion Circuit Breaker** as the operational guardrail. This guardrail does not repair the feed but safely quarantines the surface to prevent cascade failures, provided it is paired with a mandatory incident record that captures the root-cause class (metadata vs. content).

## Findings

### 1. Root Cause: Timestamp-Only Staleness Verification
The primary failure mode is the reliance on filesystem modification times (`mtime`) or `last_modified` fields as the sole determinant of feed freshness. This approach fails under three specific conditions observed in the hngh kernel environment:
*   **Idle Periods:** Feeds that are healthy but have no new commits during a patrol window appear stale because their timestamps do not advance.
*   **Partial Writes:** During atomic write operations or cache flushes, the filesystem metadata may lag behind the actual content availability, creating a transient "stale" state.
*   **Clock Skew:** NTP synchronization events can cause backward jumps in `mtime`, triggering false stale verdicts even when content is fresh.

### 2. Self-Reinforcing Failure Loop
Without an intermediate state, the first false positive does not trigger a deeper diagnostic. The second patrol run observes the same unchanged metadata and files another `feed-stale`. This transforms a single diagnostic signal into a repeated failure pattern, masking the underlying metadata/content divergence.

### 3. Guardrail Identification: Demotion at Two Consecutive Failures
The closing guardrail is the **Two-Consecutive-Failure Demotion Circuit Breaker**. This mechanism operates as follows:
*   **Trigger:** A surface files `feed-stale` on two consecutive patrol runs.
*   **Action:** The surface is demoted or quarantined from active patrol checks.
*   **Outcome:** An incident record is filed, halting the recurrence of false positives for that specific surface.

**Critical Constraint:** This guardrail is an *operational suppression*, not a *repair mechanism*. It closes the line by preventing further noise but does not fix the feed unless the incident record explicitly distinguishes between:
*   Genuinely stale content (ingestor stall).
*   Fresh content with stale metadata (clock/mtime issue).
*   Partial-write visibility artifacts.

## Recommendations

### 1. Implement Content-Aware Freshness Model
Replace timestamp-only checks with a composite freshness model. Patrol must verify at least one of the following before filing `feed-stale`:
*   **Content Hash/Revision:** Compare against expected minimum revision or hash.
*   **Explicit Freshness Marker:** Use an application-level marker (e.g., `published_at` or `ingest_seq`) rather than filesystem metadata.
*   **Bounded Probe:** Execute a lightweight content probe to confirm payload advancement.

**Rule:** `mtime` may raise suspicion but must not be the sole basis for filing `feed-stale`.

### 2. Introduce Intermediate State: `suspect_stale`
Add a state transition between `fresh` and `confirmed_stale` to break the self-reinforcing loop:
*   **Run 1 (Suspect):** If metadata indicates staleness, mark surface as `suspect_stale`. Record evidence but do not file incident.
*   **Run 2 (Probe):** Before filing `feed-stale`, execute a content-level probe.
*   **Run 3 (Confirm/Quarantine):** Only if the probe confirms content has not advanced, file `confirmed_stale`. After two confirmed observations, trigger demotion/quarantine.

### 3. Mandate Root-Cause Classification in Incident Records
Every incident filed by the Two-Consecutive-Failure guardrail must include a mandatory field specifying the root-cause class:
*   `metadata_drift` (clock/mtime issue)
*   `content_stall` (ingestor failure)
*   `write_artifact` (partial visibility)

This ensures that future incidents are actionable and prevent recurrence of the same diagnostic gap.

## Open Threads

1.  **Probe Cost Optimization:** The recommended content-level probe on Run 2 requires defining its computational cost. If the probe is expensive, it may introduce latency to patrol cycles. Further research needed on lightweight hash verification strategies in the hngh kernel.
2.  **Clock Skew Remediation:** While the guardrail suppresses false positives from clock skew, it does not fix the underlying NTP synchronization issue. A separate line should investigate host-level clock stability monitoring for patrol hosts.
3.  **Partial Write Visibility:** The diagnosis assumes atomic writes are not guaranteed in all feed paths. Verification is needed on whether the hngh kernel enforces atomic write semantics for all feed surfaces, or if additional file-locking mechanisms are required.

## References

*   **Repository Root:** `[redacted path]
*   **Prior Material:** Research beat 2026-09-18 (contracted line summary)
*   **Prior Art Pointers:**
    *   `[[sources/outcome-demotion-at-two-consecutive-failures]]` – Consecutive bad-execution cancellation circuit breaker logic.
    *   `[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]` – Research lesson on drift confirmation in scroll behavior.
    *   `[[sources/verdict-rule-drift-two-surfaces]]` – Shared verdict rule drift across surfaces.

**Note:** Specific file paths, function names, and module boundaries within the hngh kernel could not be verified from the supplied text. Recommendations are grounded in the research line’s stated repository target and prior material, but do not assert specific internal code locations beyond the repository root.
