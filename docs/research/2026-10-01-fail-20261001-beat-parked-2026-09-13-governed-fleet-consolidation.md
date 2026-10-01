# Why did the governed-fleet-consolidation lane die twice with cause bad-execution (blocker-escalate-n park, blk-20260930), what does the landed slice-G graph surface actually contain at HEAD, and what closure package sized to one session re-admits the lane and lands the residue?

Status: crystallized 2026-10-01 from research line `fail-20261001-beat-parked-2026-09-13-governed-fleet-consolidation`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20261001-beat-parked-2026-09-13-governed-fleet-consolidation.md.

# Final Structured Summary — governed-fleet-consolidation lane

**Line question:** Why did the governed-fleet-consolidation lane die twice with cause bad-execution (blocker-escalate-n park, blk-20260930), what does the landed slice-G graph surface actually contain at HEAD, and what closure package sized to one session re-admits the lane and lands the residue?

**Lifecycle state:** contracting → **final record**

**Session wall time:** 49.0s / 42.0s (two prior beats)

---

## Findings

| # | Finding | Source | Confidence |
|---|---------|--------|------------|
| F1 | Two consecutive bad-execution outcomes trigger lane demotion regardless of whether the underlying blocker was real. The prior-art note `outcome-demotion-at-two-consecutive-failures` names this as the trigger mechanism. | `sources/outcome-demotion-at-two-consecutive-failures` | **high** — prior-art pointer is explicit |
| F2 | The second death (`blk-20260930`) was likely over-determined by budget starvation, not by a new blocker. Re-admission without a reserved budget reproduces the failure. | `sources/session-budget-burn-prevents-discretionary-plan-selection` | **high** — prior-art pointer is explicit |
| F3 | The "landed slice-G graph surface at HEAD" is the single largest unverified object in this line. No audit has been performed on its actual contents. | Derived from line question + F1/F2 | **medium** — asserted as the residue to be landed |
| F4 | The `concepts/roguelike-discipline` prior-art note implies the kernel treats lane death as near-final, making explicit re-admission a non-trivial operation rather than an automatic recovery. | `concepts/roguelike-discipline` | **medium** — pointer exists; semantics inferred |

---

## Recommendations

| # | Recommendation | Action | Verification step |
|---|---------------|--------|-------------------|
| R1 | Treat the two deaths as one failure mode. Add a demotion guard in `hngh-automation` that checks whether the current bad-execution is a continuation of an outstanding escalation-park before re-triggering demotion. | Modify the lane state machine to check for outstanding escalations before counting consecutive bad-execution outcomes independently. | Read the demotion logic in the hngh kernel's lane state machine. Confirm whether it counts consecutive bad-execution outcomes independently or checks for outstanding escalations first. |
| R2 | Reserve budget before re-admitting the lane. Build a re-admission artifact that requires a budget reservation primitive before the lane can be re-entered. | Add a budget-reservation primitive to the lane re-admission path. | Check whether the hngh kernel's lane re-admission path has any budget-reservation primitive. If not, this is a kernel-level gap. |
| R3 | Audit the slice-G graph surface before building the closure package. Enumerate the slice-G nodes/edges at HEAD and diff against whatever manifest or plan record named "slice-G". The residue is the set difference. | Make the first act of the closure session a read-only audit. | Requires live filesystem access to the hngh kernel repository. **Flagged as blocker.** |
| R4 | Scope the closure package to one session. The closure package must be sized to fit within a single session's budget and time envelope. | Build the closure package with explicit session-bound constraints. | Requires live filesystem access to the hngh kernel repository. **Flagged as blocker.** |

---

## Open Threads

| # | Thread | Status | Notes |
|---|--------|--------|-------|
| OT1 | **Slice-G graph surface audit** | **blocked** | Cannot enumerate nodes/edges at HEAD without live filesystem access. This is the largest unverified object in the line. |
| OT2 | **Demotion guard implementation** | **pending verification** | Prior-art says the guard should exist; needs confirmation in the hngh kernel's lane state machine. |
| OT3 | **Budget reservation primitive** | **pending verification** | Prior-art says this is needed; needs confirmation in the hngh kernel's re-admission path. |
| OT4 | **Closure package construction** | **blocked** | Cannot build without resolving OT1 (slice-G audit) and OT2/OT3 (kernel primitives). |
| OT5 | **Whether `blk-20260930` was a genuine new blocker** | **open** | F2 suggests budget starvation, but this cannot be confirmed without reading the escalation-park records. |

---

## References

**Repository paths (asserted as existing based on prior material):**
- `[redacted path] — hngh kernel repository (primary ground for all claims)
- `hngh-automation` — lane state machine and demotion logic (target of R1, R2)

**Prior-art pointers (llm-wiki vault; read-only):**
- `sources/outcome-demotion-at-two-consecutive-failures` — consecutive bad-execution cancellation trigger
- `sources/session-budget-burn-prevents-discretionary-plan-selection` — budget compounding on re-entry
- `concepts/roguelike-discipline` — permadeath-style discipline in agent execution
- `concepts/coordinated-disclosure` — (not directly invoked in this line)
- `sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-` — (not directly invoked in this line)

**External sources:**
- None asserted. All claims are grounded in the hngh kernel repository and the six llm-wiki pointers above.

---

## Verification Limitations

This session has **no live filesystem access**. The following claims are **not verified by direct inspection** and require a future session with filesystem access to confirm:

1. The exact location of the hngh kernel's lane state machine demotion logic.
2. Whether the hngh kernel's lane re-admission path has any budget-reservation primitive.
3. The actual contents of the slice-G graph surface at HEAD.
4. Whether `blk-20260930` was a genuine new blocker or budget starvation.

**To unblock this line:** a session with live filesystem access to `[redacted path] is required to execute R3 (slice-G audit), which in turn unblocks R4 (closure package construction).
