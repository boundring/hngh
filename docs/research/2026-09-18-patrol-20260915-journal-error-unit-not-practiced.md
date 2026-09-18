# patrol: surface journal-error filed unit-not-practiced on two consecutive runs -- why does it keep failing and which guardrail closes it?

Status: crystallized 2026-09-18 from research line `patrol-20260915-journal-error-unit-not-practiced`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-patrol-20260915-journal-error-unit-not-practiced.md.

# Research Line: Patrol `unit-not-practiced` Recurrence — Final Structured Summary

**Line State:** Contracting (Final)
**Date:** 2026-09-18
**Subject:** Why the `unit-not-practiced` journal error persists across two consecutive runs and which guardrail closes it.

## Executive Summary

The recurrence of the `unit-not-practiced` journal error on two consecutive patrol runs indicates a **state persistence failure** rather than a transient detection glitch. The system correctly identifies the unit as unpracticed, but the remediation path either fails to execute, fails to commit state, or is overwritten by a race condition before the next patrol cycle. The expected guardrail (likely an automation timer or script in `hngh-automation`) is disconnected from the detection loop, creating a persistent open thread.

## Findings

### 1. Persistent State Failure Mechanism
The error recurrence implies that the "practiced" state flag is not being durably updated between patrol executions. Possible causes:
- **In-memory only state:** The practice/test execution updates state in memory but fails to persist to disk or kernel metadata before the process exits.
- **Race condition:** A concurrent patrol run reads the stale state before the remediation script completes its write.
- **Silent failure:** The remediation step executes but returns a non-zero exit code that is swallowed by the automation layer, leaving the journal error unresolved.

### 2. Guardrail Disconnect
The detection (journaling) and remediation (state update) layers are decoupled. The journal correctly files the error, but no guardrail actively suppresses or resolves it between runs. This suggests:
- The automation timer in `hngh-automation` may be misconfigured or disabled.
- The remediation script lacks idempotency or proper state commit logic.
- There is no feedback loop from remediation success back to the journal system to close the error entry.

### 3. Two-Consecutive-Run Pattern
The fact that this occurs on *two consecutive* runs (not sporadically) points to a **deterministic failure mode** rather than a flaky condition. This aligns with the prior art reference `[[sources/outcome-demotion-at-two-consecutive-failures]]`, which suggests that two consecutive failures trigger demotion or escalation logic. The system is correctly escalating, but the underlying state bug remains unaddressed.

## Recommendations

### Immediate Actions
1. **Audit State Persistence:** Inspect where the "practiced" state is stored (in-memory, local state file, or kernel metadata). Verify that the practice/test execution commits this state durably before subsequent patrol executions.
   - *Action:* Review state management logic in `hngh` and `hngh-automation`. Confirm the flag is set and persisted after successful practice.

2. **Verify Guardrail Execution:** Check whether the expected automation timer or script in `hngh-automation` is active, correctly scheduled, and executing without errors.
   - *Action:* Run the guardrail manually to confirm it resolves the state. If it does, investigate why it isn't triggering automatically.

3. **Add Feedback Loop:** Implement a mechanism where successful remediation closes the corresponding journal error entry. This prevents recurrence of the same error if state is correctly updated.

### Long-Term Improvements
1. **Idempotency Guarantee:** Ensure the remediation script is idempotent and safe to run multiple times without side effects.
2. **Race Condition Mitigation:** Add file locking or atomic writes to prevent concurrent patrol runs from reading stale state.
3. **Monitoring:** Add alerting if the same journal error recurs after a successful remediation attempt, indicating a deeper persistence issue.

## Open Threads

1. **State Storage Location:** The exact location of the "practiced" state flag (in-memory, file, kernel metadata) is unverified. This requires inspection of `hngh` source code and `hngh-automation` scripts.
2. **Guardrail Identity:** The specific guardrail script or timer responsible for closing this loop is not identified. It may be in `hngh-automation`, but the exact file path and configuration are unverified.
3. **Journal Closure Mechanism:** How journal errors are closed (manually, automatically, via state change) is unclear. This requires review of the journaling subsystem in `hngh`.

## Verification Constraints

**I cannot verify local filesystem paths in `[redacted path] or the current repository from this environment.** I will not assert specific file paths (e.g., `src/journal.c`, `guardrails/patrol.sh`) and explicitly state where verification against the local repository is required.

- **State persistence logic:** Requires inspection of `hngh` source code to confirm where "practiced" state is stored and committed.
- **Guardrail implementation:** Requires inspection of `hngh-automation` to identify the specific script or timer responsible for remediation.
- **Journal closure mechanism:** Requires inspection of the journaling subsystem in `hngh` to understand how errors are closed.

## References

1. `[[sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-]]` — Research Lesson: Does the obs 2026-08-25 hngh-automation...
2. `[[sources/LES-fail-20260915-Does-the-research-lines-tsv-schema-inclu]]` — Research Lesson: Does the research lines tsv schema include...
3. `[[sources/LES-fail-20260915-Has-R1-systemctl-status-list-timers-jour]]` — Research Lesson: Has R1 systemctl status list timers jour...
4. `[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]` — Research Lesson: If drift is confirmed in the scroll beha...
5. `[[sources/outcome-demotion-at-two-consecutive-failures]]` — Consecutive bad-execution cancellation c...
6. `[[sources/obs-2026-08-25-guardrail-bug-filed-upstream-hngh-analytics-live-readme-curr]]` — Obse...

**Note:** External sources cannot be verified from this environment. The above references are pointers to prior art in the llm-wiki vault and require local inspection for full context.
