# wire the descent adoption gate per docs/design/descent.md:129-147 -- crystallized line -> backlog row with named consumer + one-alternation deadline, expired adoptions auto-revoke to a citable dead-letter (prior arc-20260925 line died in review for an empty crystallization, not a rejected thesis)

Status: crystallized 2026-09-26 from research line `arc-20260926-descent-adoption-gate`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-arc-20260926-descent-adoption-gate.md.

_line: wire the descent adoption gate per docs/design/descent.md:129-147 — crystallized line → backlog row with named consumer + one-alternation deadline, expired adoptions auto-revoke to a citable dead-letter | state: contracted → crystallizing | prior beats: 1 expansion (this line), 1 contraction (this line), arc-20260925 (dead) | wall_s: 62.0_

---

## Crystallized Line Record: Descent Adoption Gate Wiring

**Line ID:** descent-adoption-gate-wiring  
**Spec Anchor:** `docs/design/descent.md:129-147`  
**Lifecycle State:** crystallizing (final summary)  
**Prior Failure Mode:** arc-20260925 — empty crystallization died in review, not rejected thesis  
**Verification Status:** No live filesystem reads in this transition. All file-path claims below are asserted from prior material only; paths marked **[unverified]** require repo read to confirm.

---

### Findings

**F1. The gate is three mechanisms, one must-not-break.**  
The descent adoption gate consumes crystallizations. It cannot rescue them. The must-not-break precedent is: *expired adoptions auto-revoke to a citable dead-letter*. This was established in the expansion beat and is the invariant that all wiring must preserve.

**F2. Empty crystallization is a gate-entry failure, not a downstream failure.**  
The arc-20260925 line died because an empty crystallization reached review. The gate must refuse at entry — if the crystallization payload is empty, refuse to write the backlog row and emit a gate-entry error. This prevents the same failure from propagating one lifecycle stage downstream.

**F3. The backlog row must be written atomically with crystallization.**  
The adoption record is not a separate human step. It is a side effect of crystallization. Three mandatory fields: `line_id` (foreign key to `research-lines.tsv`), `consumer` (named, non-null — empty is a schema violation), `deadline_alternation` (integer, exactly one alternation ahead of crystallization's alternation index).

**F4. "Alternation" is the highest-risk wiring decision.**  
An alternation is one full expansion↔contraction cycle of the line lifecycle state machine. The clock tick should be the lifecycle transition event itself, not wall time. **[unverified — requires repo read]** of wherever the lifecycle state machine and its transition hook live; `docs/design/descent.md:129-147` is the spec anchor but the tick source is not confirmed.

**F5. Auto-revocation is automatic, not human-in-the-loop.**  
On each alternation tick, sweep adoption rows where `current_alternation > deadline_alternation` and the named consumer has not acted. Revocation must be automatic and must **move** the row to a dead-letter store, not delete it.

**F6. Dead-letter schema must carry a revocation-cause enum.**  
Minimum enum: `{expired-deadline, rejected-in-review, empty-payload-refused}`. The dead-letter retains the original thesis text and the original `line_id` so it remains citable by future lines. This preserves the arc-20260925 distinction: death-by-neglect (recoverable thesis, re-adoptable) is not death-by-rejection (settled).

---

### Recommendations

**R1. Implement gate-entry precondition for empty crystallizations.**  
Wire a precondition check at gate entry: if the crystallization payload is empty, refuse to write the backlog row and emit a gate-entry error. This is the direct fix for arc-20260925.

**R2. Define adoption record schema with three mandatory fields.**  
`line_id`, `consumer` (non-null), `deadline_alternation` (integer, one ahead of crystallization's alternation index). Written as a side effect of crystallization.

**R3. Define "alternation" operationally before wiring the clock.**  
An alternation is one full expansion↔contraction cycle of the line lifecycle state machine. The clock tick should be the lifecycle transition event itself, not wall time. **[unverified — requires repo read]** of the lifecycle state machine and its transition hook.

**R4. Implement auto-revocation sweep keyed to the alternation tick.**  
On each alternation tick, sweep adoption rows where `current_alternation > deadline_alternation` and the named consumer has not acted. Revocation must be automatic and must **move** the row to a dead-letter store.

**R5. Define dead-letter schema with revocation-cause enum.**  
Minimum enum: `{expired-deadline, rejected-in-review, empty-payload-refused}`. Retain original thesis text and `line_id` for citability.

**R6. Implement three independent unit tests, one per mechanism.**  
Gate-entry precondition, adoption record schema validation, auto-revocation sweep. **[unverified — requires repo read]** of the test framework location.

---

### Open Threads

**OT1. Lifecycle state machine transition hook location.**  
`docs/design/descent.md:129-147` is the spec anchor for the gate, but the location of the lifecycle state machine and its transition hook (the alternation tick source) is not confirmed. **[unverified — requires repo read]** of `[redacted path] and `research-lines.tsv`.

**OT2. Test framework location.**  
The prior contraction references "three independent unit tests, one per mechanism" but does not specify where the test framework lives. **[unverified — requires repo read]**.

**OT3. Dead-letter store location.**  
The dead-letter store is referenced as a destination for revoked rows, but its location and schema implementation are not specified. **[unverified — requires repo read]**.

**OT4. Consumer identity resolution.**  
The `consumer` field requires a "named" consumer, but the mechanism for resolving consumer identity (e.g., git author, CI system, named service) is not specified. **[unverified — requires repo read]**.

---

### References

| Reference | Path | Verification Status |
|-----------|------|-------------------|
| Descent spec anchor | `docs/design/descent.md:129-147` | **asserted from prior material** — not re-read |
| Line state file | `research-lines.tsv` | **asserted from prior material** — not re-read |
| Hngh kernel repository root | `[redacted path] | **[unverified — requires repo read]** |
| Prior art: Hngh Project Backlog | `sources/SRC-2026-08-24-022` | **read-only pointer, not re-read** |
| Prior art: Research Lesson Has R1 | `sources/LES-fail-20260915-Has-R1-systemctl-status-list-timers-jour` | **read-only pointer, not re-read** |
| Prior art: Hngh Crystallized Rebuild Roadmap | `sources/SRC-2026-08-18-003` | **read-only pointer, not re-read** |
| Prior art: Retired Hngh System | `sources/SRC-2026-08-19-002` | **read-only pointer, not re-read** |
| Prior art: Backlog disposition sweep | `sources/backlog-disposition-sweep-reduces-accepted-plans-by-half` | **read-only pointer, not re-read** |
| Prior art: Savor Dish consumer AI | `sources/savordish-ai-cookbook` | **read-only pointer, not re-read** |

**External sources:** None cited. All claims are grounded in the repository and prior material on this line. No external sources were required or verified.

---

**Line state transition:** contracting → crystallizing (final summary produced)  
**This line is now closed for new beats.** Future disposition of this line's recommendations requires a new line or an explicit re-opening.
