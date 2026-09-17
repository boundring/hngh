# How does the "Composite Seal" pattern interact with `hngh-automation`'s current retention policiesspecifically, can a "hold marker" be added to a sealed segment without invalidating the original signature (e.g., via a sidecar or re-signing)

Status: crystallized 2026-09-17 from research line `fail-20260917-How-does-the-Composite-Seal-pattern-inte`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260917-How-does-the-Composite-Seal-pattern-inte.md.

# Research Line: Composite Seal × Retention Hold Marker — Final Contracted Record

**Line:** How does the "Composite Seal" pattern interact with `hngh-automation`'s current retention policies—specifically, can a "hold marker" be added to a sealed segment without invalidating the original signature (e.g., via a sidecar or re-signing)?
**State:** expanding → contracting → **contracted (final)**
**Date:** 2026-09-17

---

## Findings

### F1 — A hold marker cannot be embedded in the sealed byte stream

Under the Composite Seal pattern as described in this line's prior material, the segment's cryptographic boundary covers a contiguous byte sequence from time-of-seal ($T_0$) onward. Any mutation to bytes within that boundary—including appending a hold flag—invalidates the seal. This is not an implementation limitation but a structural property of the pattern: the hash input is fixed at $T_0$, and verification recomputes over the same byte range.

**Verification status:** This finding rests on the architectural definition of the composite seal as reasoned in prior beats. I cannot confirm from this session that a file such as `[redacted path] or equivalent exists implementing exactly this boundary semantics. The prior art entry `[[sources/SRC-2026-08-24-026]]` (Hngh Roadmap, 2026-08-24) is the closest pointer to a concrete implementation state, but its full content was not available in this beat's context. Treat F1 as **pattern-level sound** pending code-level confirmation against the kernel tree.

### F2 — Sidecar hold index is the only mechanism that preserves seal integrity

A hold marker stored *outside* the seal boundary—whether as a sidecar file (`<segment-id>.hold`), an index-table row, or a wrapper header field not covered by the seal's hash input—leaves the sealed segment bit-for-bit identical. The retention engine can then make delete/archive decisions by querying this external structure without ever re-verifying the seal for hold-status purposes.

**Verification status:** No file path in `[redacted path] or a sibling `hngh-automation` tree was confirmed in this session to already contain such a sidecar mechanism. The prior art entry `[[sources/LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca]]` (truncated title: "What are the exact file paths for the ca…") indicates that an earlier beat attempted to pin down concrete paths and **failed** to do so. F2 is therefore a **design recommendation**, not a description of existing code.

### F3 — Re-signing to embed a hold is architecturally unsound

Three independent objections, all established in prior beats:

| # | Objection | Consequence |
|---|-----------|-------------|
| 1 | Original $T_0$ signature is replaced | Loss of time-of-seal proof; cannot demonstrate the segment was unaltered between $T_0$ and re-sign at $T_1$ |
| 2 | Full re-hash of potentially large segment for a single flag | Disproportionate I/O and CPU cost vs. writing a small sidecar pointer |
| 3 | Peer nodes must track which signature version is current | Introduces consensus/verification-state complexity the current design avoids |

If a future requirement demands the hold be *cryptographically bound* to the segment (tamper-evident hold), the correct pattern is a **separate signed attestation** over `(segment-hash ‖ hold-flag ‖ holder-id ‖ timestamp)`, stored alongside—not in place of—the original seal.

**Verification status:** Same as F1/F2. The reasoning is structural; no code-level counter-example was found, but none was confirmed either.

### F4 — Retention engine must be decoupled from seal verification for hold decisions

The deletion/archive pipeline should follow: enumerate candidates → query sidecar hold index → act only on unheld candidates → log decision in a sealed/signed audit trail. The engine never re-verifies a seal to decide *whether* to delete; it checks the sidecar. Seal verification remains a separate concern (integrity check), not a gate for retention logic.

**Verification status:** No confirmed file path for the retention/deletion pipeline in `hngh-automation` was established in this session. The prior art entry `[[sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-]]` (truncated: "Does the obs…") suggests an earlier beat investigated whether an observation/retention mechanism exists in `hngh-automation` and **failed** to confirm specifics. F4 is a **design constraint**, not a description of verified code.

---

## Recommendations

### R1 — Hold state must be external to the seal boundary

Any retention-hold decision (legal hold, audit preservation, debugging pin) must be recorded in a structure **not covered by the composite seal's hash input**. The sealed segment's byte sequence remains bit-for-bit identical from $T_0$ onward. The retention job must be *read-only* with respect to the sealed payload; if it ever writes into seal-covered bytes, every subsequent verification pass reports integrity failure.

### R2 — Retention engine queries the hold index before acting

Pipeline order: enumerate → query sidecar → act on unheld only → log decision (segment-id, hold-status, action-taken) in an audit trail that is itself sealed or signed. This keeps the retention engine decoupled from seal verification.

### R3 — Do not re-sign to add a hold

Rejected for audit-trail loss, cost, and verification-state complexity (see F3). If cryptographic binding is later required, use a separate signed attestation stored alongside the original seal.

### R4 — Hold release must be atomic and logged

Lifting a hold transitions the sidecar entry to `released` (or removes it) and produces an audit record signed by the issuing authority, answering: *who held it, when was it released, was the segment still intact at release time?*

---

## Open Threads

1. **Code-level confirmation of seal boundary semantics.** The composite seal pattern is reasoned at the architectural level throughout this line. No file in `[redacted path] was opened or confirmed in any beat of this line to show the exact hash-input construction, byte-range definition, or verification routine. A future line (or a targeted probe) should open the seal implementation and confirm that the boundary is indeed fixed at $T_0$ with no extensibility hook.

2. **Exact file paths for `hngh-automation` retention pipeline.** Two prior-art entries (`LES-fail-20260915-Does-the-obs…`, `LES-fail-20260915-What-are-the-exact-file-paths…`) both record **failures** to pin down concrete paths. The retention/deletion/archive code location in `hngh-automation` remains unconfirmed. This is the single largest grounding gap in this line.

3. **Sidecar format decision.** The prior material identifies *that* a sidecar is needed but does not resolve *which* form: file-per-segment (`<segment-id>.hold`), a shared index table (SQLite/LevelDB row), or a wrapper header field. Each has different operational characteristics (file-count explosion vs. single-writer contention vs. wrapper-parsing cost). This decision should be made in the implementation beat, not here.

4. **Audit-trail sealing mechanism.** R2 and R4 require the decision log to be "sealed or signed." No prior beat confirmed whether `hngh-automation` has an existing audit-log facility that is itself sealed, or whether this would need to be built. The prior art entry `[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]` (truncated: "If drift is confirmed in the scroll beha…") touches on a related verification concern but its full content was not available here.

5. **Relevance of "surviving class on 1 host" (R1 from prior art).** The entry `[[sources/LES-fail-20260915-If-R1-confirms-1-surviving-class-on-1-ho]]` (truncated) references a finding about a surviving class on a single host. Its bearing on the composite-seal × hold-marker question is unclear from this contracted record; it may be tangential or may constrain the sidecar's deployment topology.

---

## Grounding & Verification Gaps (Consolidated)

This line's reasoning is **pattern-level and architectural**. No beat in this line successfully opened a source file in `[redacted path] or a confirmed `hngh-automation` tree to verify:

- The exact hash-input construction of the composite seal
- The existence (or absence) of a retention/deletion pipeline
- The current format of any segment metadata or index structures
- Whether a sidecar mechanism already exists in prototype form

The prior art vault contains **four `LES-fail` entries** and **one `SRC` roadmap pointer**, all with truncated titles in this session's context. None provided verified file paths. The line's findings are therefore sound as *design constraints derived from the pattern definition* but are **not yet grounded in confirmed code**.

No external sources beyond the prior-art vault pointers were required or used. Where the reasoning invokes general cryptographic-hygiene principles (e.g., "re-signing destroys the time-of-seal proof"), these are standard properties of hash-based signatures and do not require citation; they are stated as structural facts about how Merkle/hash chains work, not as claims requiring external verification.

---

## References

- `[[sources/SRC-2026-08-24-026]]` — Hngh Roadmap (current state, 2026-08-24). Closest pointer to implementation state; full content not available in this beat.
- `[[sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-]]` — Research Lesson (failed): investigation into whether an observation/retention mechanism exists in `hngh-automation`. Title truncated in vault index.
- `[[sources/LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca]]` — Research Lesson (failed): attempt to pin exact file paths for the candidate retention code. Title truncated.
- `[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]` — Research Lesson (failed): drift confirmation in scroll behavior; relevance to this line unconfirmed.
- `[[sources/LES-fail-20260915-If-R1-confirms-1-surviving-class-on-1-ho]]` — Research Lesson (failed): R1 finding on surviving class; bearing on this line unclear.
- `[[concepts/hngh-lessons-current]]` — Hngh Lessons, current (created 2026-09-07). General lessons context.
- `[redacted path] — hngh kernel repository root. **No file within this tree was opened or confirmed in any beat of this line.** Cited as the grounding target; no specific sub-path is asserted to exist.

---

*This record is the contracted, final state of the line. The line's motion continues on idle hosts; this summary is its lasting crystallization, not a terminal stop.*
