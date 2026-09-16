# Where does the hngh reconciliation loop persist its state, and is that storage mechanism resilient to multi-process CLI execution?

Status: crystallized 2026-09-16 from research line `fail-20260915-Where-does-the-hngh-reconciliation-loop-`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260915-Where-does-the-hngh-reconciliation-loop-.md.

# Final Structured Summary

**Research line:** Where does the hngh reconciliation loop persist its state, and is that storage mechanism resilient to multi-process CLI execution?
**Lifecycle:** contracting → final record
**Date of crystallization:** 2026-09-16

---

## Findings

### F1 — State persistence location: unresolved

No source file in `/home/bricker/Projects/etc/hngh` was examined during this line's lifetime. The sole prior beat (expanding phase, 2026-09-16) states explicitly that "without filesystem access, architectural deduction is speculative." Every inference about where state lives—whether a single JSON file, a directory of tick logs, an SQLite database, or some other mechanism—was derived from assumed language conventions (Rust, inferred from `.rs` extension) and generic CLI patterns, not from repository contents.

**No verified claim can be made about the storage path, format, or write strategy.**

### F2 — Multi-process resilience: unresolved

Whether the persistence mechanism tolerates concurrent invocation (multiple processes triggered by systemd timers, cron, or manual CLI execution) is undetermined. The prior beat identified a last-writer-wins race as the *primary risk if* no locking exists, but this was a conditional deduction from an unexamined codebase, not an observation of actual behavior.

**No verified claim can be made about concurrency safety.**

### F3 — Conditional engineering guidance (unverified)

The expanding phase produced three recommendations:

1. Atomic-write directory pattern (write-to-temp + rename) for crash resilience.
2. Advisory file locking (`flock` / `fcntl`) on a dedicated lock file for single-writer enforcement.
3. Idempotent drift correction with application-level compare-and-swap semantics.

These are sound engineering practices for the described threat model, but they are **proposals to validate against source**, not findings grounded in observed repository contents. They carry no more epistemic weight than any other reasonable design suggestion for a stateful CLI loop.

### F4 — Drift as a confirmed failure mode (externally corroborated)

Prior art `LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha` establishes that drift is a *confirmed* failure mode in the hngh automation context. This is the only externally corroborated fact linking to this line's scope. The causal relationship between state staleness and apparent drift (i.e., whether a stale read *produces* a false drift signal) remains uninvestigated.

### F5 — Absence of verification is itself a finding

The honest result of this research line is negative: the two core questions cannot be answered from the materials available to it. The line has exhausted what can be deduced without filesystem access. This is recorded so that future beats on related lines do not re-derive the same speculative conclusions under the impression that they are grounded.

---

## Recommendations

| # | Action | Rationale |
|---|--------|-----------|
| 1 | Obtain filesystem access to `/home/bricker/Projects/etc/hngh`; locate the reconciliation loop's entry point, its state I/O calls, and any lock acquisition logic. | Single action that resolves both core questions. |
| 2 | Inspect `hngh-automation` orchestration scripts and deployment configuration (systemd units, cron entries) to determine whether multi-process invocation is *actually* scheduled. | The resilience question is moot if only one process ever runs; the threat model must be confirmed before engineering effort is directed. |
| 3 | If source access confirms a single-file state store without locking, convert F3's conditional recommendations into concrete engineering tasks with file paths. | Moves from speculation to actionable work. |
| 4 | Re-open this line if any of the above investigations produce new evidence. | The current record is an absence-of-verification, not a positive finding; the questions remain live. |

---

## Open Threads

| Thread | Status | Blocking condition |
|--------|--------|--------------------|
| Identify state persistence path and format in hngh kernel source | **Open** | Requires filesystem access to `/home/bricker/Projects/etc/hngh` |
| Determine whether multi-process invocation is actually scheduled (timers, cron, manual) | **Open** | Requires inspection of `hngh-automation` deployment configuration |
| Validate or refute the last-writer-wins race hypothesis against actual code | **Open** | Dependent on the two threads above |
| Clarify causal relationship between drift failure mode and state staleness | **Open** | Requires runtime observation or source-level tracing of the reconciliation loop |

---

## References

- **Prior beat, 2026-09-16** (expanding → contracting; model: unsloth:unsloth/Qwen3.8-27B-GGUF) — sole prior material on this line. Contains no verified file-path citations from the hngh kernel repository. All architectural claims are explicitly labeled as speculative deductions.
- **`[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]`** — establishes drift as a confirmed failure mode in the hngh automation context. No file paths cited in available excerpt.
- **`[[sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-]]`** — references an observation of `hngh-automation`; no file paths cited in available excerpt.
- **`[[sources/SRC-2026-08-24-030]]`** — "Case Study: Overnight Multi-Agent Sprint (2026-08-24)." Contextual; no direct bearing on the state persistence mechanism.
- **`[[concepts/roguelike-discipline]]`** — conceptual framework for agent execution discipline. Not directly relevant to the storage-mechanism question.

*No file paths from `/home/bricker/Projects/etc/hngh` are cited in this summary because none could be verified as existing during the lifetime of this research line. All prior material on this line explicitly disclaims filesystem access. Any claim requiring verification against that repository is marked as such above rather than asserted.*
