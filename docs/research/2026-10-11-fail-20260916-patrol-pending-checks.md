# Six converged pending named-checks (correction-f6 "something looks off" plus five 2026-09-15 deck-UI defect reports) have sat in state/pending-checks.tsv for 26 days re-firing the patrol:pending-checks identity: can any become a deterministic patrol route, or should all six be parked and the deck complaints routed to the active ui-evolve lane?

Status: crystallized 2026-10-11 from research line `fail-20260916-patrol-pending-checks`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260916-patrol-pending-checks.md.

# Research Line: Six Converged Pending Named-Checks — Final Crystallization

**Line state:** `expanding` → `contracting` → **final summary**  
**Date:** 2026-10-11  
**Model:** unsloth:unsloth/Ornith-1.0-9B-GGUF  
**Wall-clock elapsed:** 26 days  

---

## Findings

### 1. The Six Checks Are Stuck

Six named-checks have been in `state/pending-checks.tsv` for 26 days. This is not a transient state — it is a structural blockage. The patrol:pending-checks identity re-fires on idle hosts, but no resolution has occurred. The line has been running in a loop without progress.

**Observable fact:** `state/pending-checks.tsv` exists and contains these entries. The file path is grounded in the repository surface.

### 2. `correction-f6` Cannot Become a Patrol Route Without a Script

The prior beat hypothesized that `correction-f6` could be decomposed into detect → correct → verify → archive. This hypothesis was tested against what is actually observable:

- The label `correction-f6` exists in the TSV, but it does not encode correction logic
- No correction-script attachment is present in the repository
- No resolvable target path exists for the correction to act upon
- No verification check is defined

**Finding:** The patrol cannot execute a detect → correct → verify → archive loop without a script. The label alone is insufficient.

### 3. `ui-evolve` Lane State Is Unknown

The five deck-UI reports (2026-09-15) were routed to `ui-evolve` as a target lane. However:

- No evidence confirms `ui-evolve` is currently an active lane
- No evidence confirms `ui-evolve` has capacity
- No evidence confirms `ui-evolve` acceptance criteria

**Finding:** Parking the five reports in `ui-evolve` without lane-state verification creates a dead end identical to the current state. The temporal anchor (2026-09-15) does not guarantee lane continuity.

### 4. Hngh-Native Supervision Is the Correct Direction, But Requires Kernel Work

The prior beat cited `[[sources/supervision-must-be-hngh-native]]` as prior art. The principle is clear: supervision patterns must become Hngh-native mechanisms, not raw TSV entries. However:

- The `pending-checks.tsv` file is a raw TSV, not an Hngh-native mechanism
- No Hngh-native supervision wrapper exists for the pending-checks lifecycle
- Kernel-level work is required to implement this

**Finding:** This is the most actionable angle, but it requires work in the hngh kernel repository, not just a decision about the six checks.

---

## Recommendations

### 1. Park `correction-f6` with a Script-Dependency Note

Do not attempt to fold `correction-f6` into patrol without a correction-script attachment. Park it with an explicit note:

```
correction-f6: parked — requires correction-script attachment before patrol routing
```

This prevents the patrol from re-firing on a non-routable check.

### 2. Do Not Route the Five Deck-UI Reports to `ui-evolve` Without Lane Verification

Before routing the five 2026-09-15 deck-UI reports to `ui-evolve`, verify lane state. If `ui-evolve` is inactive or undefined, tag the reports with `ui-evolve-inactive` rather than silently parking them.

### 3. Implement Hngh-Native Supervision for `pending-checks`

This is the structural fix. The `pending-checks.tsv` identity must be wrapped in an Hngh-native mechanism. This requires:

- Kernel-level work in `[redacted path]
- A supervision wrapper that replaces raw TSV entries with Hngh-native state
- Integration with the patrol:pending-checks identity

### 4. Route Deck Complaints to the Active `ui-evolve` Lane (If Verified)

If `ui-evolve` is confirmed active with capacity, route the five deck-UI reports there. If not, keep them in `state/pending-checks.tsv` with explicit tags.

---

## Open Threads

### 1. Correction-Script Attachment for `correction-f6`

The correction logic for `correction-f6` is not present in the repository. This thread remains open until a script is attached or the check is redefined.

### 2. `ui-evolve` Lane State Verification

The lane state of `ui-evolve` is unknown. This thread requires investigation in the repository or kernel to confirm whether the lane is active.

### 3. Hngh-Native Supervision Implementation

The structural fix for `pending-checks` requires kernel-level work. This thread is open until implementation begins in `[redacted path]

### 4. External Source Verification

Claims about `ui-evolve` lane state, acceptance criteria, and backlog require external sources that I cannot verify from the repository. I have not asserted these as findings.

---

## References

### Repository Grounding

- `state/pending-checks.tsv` — the file containing the six pending named-checks (observable, grounded in repository surface)
- `[redacted path] — the hngh kernel repository (cited for kernel-level supervision work)

### Prior Art (llm-wiki vault; read-only pointers)

- `[[sources/supervision-must-be-hngh-native]]` — supervision patterns must become Hngh-native mechanisms, not raw TSV entries
- `[[sources/async-proof-pattern-for-long-drop-ins]]` — prove long-running drop-ins with background job

### External Sources

- Claims about `ui-evolve` lane state, acceptance criteria, and backlog require external sources that I cannot verify. I have not asserted these as findings.

---

## Line Closure

This line has reached its final summary. The six checks remain in `state/pending-checks.tsv`. Three angles were evaluated:

1. **`correction-f6` as patrol route** — not routable without a script; parked with dependency note
2. **`ui-evolve` lane capacity** — lane state unknown; routing requires verification
3. **Hngh-native supervision** — correct direction, requires kernel-level work

The line is in `contracting` state. No further expansion is warranted until one of the open threads is resolved. The structural fix (Hngh-native supervision) is the only angle that can permanently resolve the 26-day blockage.

**Line status:** final summary produced. Awaiting kernel-level work or script attachment to resume.
