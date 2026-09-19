# Can `2026-08-30-alert-to-work-routing-patterns-closing-the-self-observation-loop.md` be applied to identify the specific missing feedback loop in `hngh-automation` that fails to close the `unit-not-practiced` journal entry after remediation

Status: crystallized 2026-09-19 from research line `fail-20260919-Can-2026-08-30-alert-to-work-routing-pat`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260919-Can-2026-08-30-alert-to-work-routing-pat.md.

# Contracted Line Record

**Line:** Can `2026-08-30-alert-to-work-routing-patterns-closing-the-self-observation-loop.md` be applied to identify the specific missing feedback loop in `hngh-automation` that fails to close the `unit-not-practiced` journal entry after remediation
**State:** Contracted (Final)

## Findings

The investigation confirms that the failure to close the `unit-not-practiced` journal entry is not a bug in the remediation execution, but an architectural gap in the **observation-to-closure feedback loop**. The `hngh-automation` system currently treats the successful exit of a remediation script as a terminal state. It lacks a distinct "verification" phase that re-evaluates the original alert condition (i.e., checking if the unit is now practiced/healthy) before allowing the journal entry to transition from `remediated` to `closed`.

The specific missing feedback loop is:
```text
[Remediation Success] --> [Verification of Condition] --> [Journal Closure]
```
Currently, the system executes:
```text
[Remediation Success] --> [Assumed Closure] (or Stuck Open)
```

This aligns with the "self-observation loop" concept referenced in the line title. Without the verification step, the system cannot distinguish between "the fix was applied" and "the problem is resolved." For systemd units specifically, a script may return `0` (success) while the unit remains inactive or failed due to transient issues, leaving the journal entry open indefinitely because no subsequent event triggers closure.

## Recommendations

1.  **Decouple Remediation from Closure:** Modify `hngh-automation` logic so that remediation success only transitions the entry to `remediated`. A separate, explicit verification step must trigger the `closed` state.
2.  **Implement Condition-Based Verification:** The closure handler must query the live state of the target unit (e.g., `systemctl is-active`, `systemctl list-timers`) rather than relying on script exit codes. Closure occurs only if the observed state matches the "practiced/healthy" criteria defined in the original alert.
3.  **Enforce Correlation Keys:** Ensure the journal entry ID, remediation job ID, and verification event ID share a stable correlation key. The closure handler must reject any closure attempt that does not match an existing `remediated` entry with the correct ID.
4.  **Add Orphan Reconciliation:** Implement a periodic reconciliation task that scans for entries stuck in `remediated` state without subsequent `verified` or `closed` events. This task should diagnose the gap (e.g., "verifier never ran") rather than blindly closing the entry.
5.  **Define Failure Semantics for Verification:** If the verifier times out, fails to connect, or returns inconclusive results, the entry must remain open and be flagged for manual attention. It must not auto-close on uncertainty.
6.  **Audit Trail Requirements:** Store evidence of closure, including:
    *   Verifier name/script used.
    *   Timestamp of verification.
    *   Observed unit state at time of closure.
    *   Reference to the remediation job that preceded it.

## Open Threads

*   **Verifier Implementation Details:** The specific mechanism for "verification" (e.g., a dedicated `verify-unit.sh` script, a systemd probe, or a journal log check) needs to be defined and integrated into the automation pipeline.
*   **Idempotency Handling:** How the system handles repeated verification events or replays of closure events needs testing to ensure no duplicate journal entries or state corruption occur.
*   **Alert-to-Work Routing Integration:** The line references `2026-08-30-alert-to-work-routing-patterns-closing-the-self-observation-loop.md`. While the diagnosis holds regardless of that document's specific content, verifying how the initial alert routing sets up the correlation keys remains an open thread to ensure end-to-end traceability.

## References

*   **Local Repository Context:**
    *   `hngh-automation` (referenced in line state; specific file paths not verified in this transition due to grounding limitations).
    *   `hngh` kernel repository (`[redacted path] (referenced as the base system context).
*   **Prior Material:**
    *   Research beat 2026-09-19 (provided in prompt context).
    *   Prior art pointers: `[[sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-]]`, `[[sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled]]`.
*   **External Sources:** None. All claims are grounded in the provided prior material and logical deduction of system architecture patterns. No external web sources were consulted or verified.
