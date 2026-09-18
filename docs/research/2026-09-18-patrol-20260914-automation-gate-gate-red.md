# patrol: surface automation-gate filed gate-red on two consecutive runs -- why does it keep failing and which guardrail closes it?

Status: crystallized 2026-09-18 from research line `patrol-20260914-automation-gate-gate-red`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-patrol-20260914-automation-gate-gate-red.md.

# Lasting record: patrol — `automation-gate` filed `gate-red` on two consecutive runs

**Line:** patrol: surface automation-gate filed gate-red on two consecutive runs -- why does it keep failing and which guardrail closes it?  
**Lifecycle state:** contracting — final structured summary as the line’s lasting record.  
**Evidence posture:** This record is grounded only in the line state provided for this transition and the named hngh kernel repository root, `[redacted path] No external sources are used. No concrete file paths beyond that repository root are cited here because their existence cannot be verified from this transition.

---

## Findings

### 1. The repeated `gate-red` should be treated as deterministic, not transient
The line’s prior material treats two consecutive `gate-red` outcomes as evidence of a persistent condition rather than a flaky or one-off failure. The working interpretation is that the gate keeps failing because some precondition remains unsatisfied across runs.

This does **not** yet identify the exact root cause. It establishes the diagnostic posture: do not retry blindly; inspect what guardrail tripped and why its precondition was still false on the second run.

### 2. The candidate failure classes are three
The line narrows the likely persistent conditions to:

1. **Missing documentation attribution

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
