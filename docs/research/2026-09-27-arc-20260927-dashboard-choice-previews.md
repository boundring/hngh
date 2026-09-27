# How should operator-item choices always carry outcome preview text in newspaper.json composition?

Status: crystallized 2026-09-27 from research line `arc-20260927-dashboard-choice-previews`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-arc-20260927-dashboard-choice-previews.md.

# Crystallization — Research Line Final Record

**Line:** How should operator-item choices always carry outcome preview text in newspaper.json composition?
**Lifecycle state:** contracting → **crystallized** (this is the line's lasting record; the line closes here except for the repo-verification pickups listed under Open Threads, which transfer to whoever next has filesystem access to the kernel).
**Access disclosure (carried from prior beat, still in force):** This line never had read access to the working repository or to `[redacted path] Accordingly, **no repository file path is asserted anywhere in this record**. The only grounded citations are the four vault prior-art pointers supplied in the transition packet. Every claim that would require a repo path is explicitly marked `[unverified]` and collected as a pickup task rather than asserted.

---

## Findings

**F1 — Preview text is derived state, not stored state.** A preview is a claim about what an operator item *will do now*; an item's lifecycle state changes (notably via demotion after two consecutive bad executions — see the outcome-demotion prior art). Any preview string persisted as an item field can therefore become false the moment the item's state changes. Preview must be a pure function of current state, computed at composition time. The newspaper.json artifact may *record* the computed result; the item schema-of-record must not *own* one.

**F2 — Dual representations of one behavior always drift.** The scroll-behavior lesson is directly applicable: if preview text and execution behavior are authored or computed by two separate code paths, they will diverge, and the divergence will be invisible until it matters. This finding motivates the single-path design in R2 and the observational enforcement in R4.

**F3 — Long-running items make synchronous preview impossible, so the invariant must split.** (Completed from the truncated prior beat.) Async operator items cannot produce a true outcome preview at composition time. The async-proof prior art supplies the resolution: bind a provisional preview to the identity of the background proof job, so the composed artifact carries a *qualified* claim ("expected outcome — proof pending") rather than an unqualified prediction. A provisional preview without a bound proof handle is just a guess with formatting.

**F4 — "Always carry preview text" is only durable as a gate, not a convention.** Style rules erode silently. If composition can succeed while an item lacks preview text, it eventually will. The invariant survives only if the composer rejects (or loudly marks) items with no computable preview — see R5.

---

## Recommendations (R1–R6, final)

**R1 — Preview is computed at composition time, never stored.** Composition calls something like `render_preview(item_state) -> Preview` at build time, as a pure function of the item's current lifecycle state (fresh / demoted / pending-proof per the outcome-demotion rule). newspaper.json may record the computed preview in the emitted artifact; the item schema-of-record must not contain a `preview` field.

**R2 — One code path for preview and execution.** The preview renderer must be a dry-run/projection mode of the same function that realizes the choice — preview = outcome minus side effects. If items expose an execute/apply entry point, extend it with a `dry_run` flag or a sibling `project(item, context)`. Never maintain a separate human-authored preview string. `[unverified: the item execution interface's actual shape]`

**R3 — Async items get bound-provisional previews.** Split the invariant by item kind:
- *Final previews* for synchronous items — full outcome text at composition time.
- *Provisional previews* for async items — rendered as "expected outcome — proof pending," carrying the background proof job's identity.

Suggested shape: `preview = { text, status: "final" | "provisional", proof_ref?: <job handle> }`. Composition must never emit an unqualified prediction for an unproven item. `[unverified: whether kernel job handles are serializable into newspaper.json fields]`

**R4 — Parity is enforced observationally, not trusted structurally.** Continuously compare realized outcome text against the preview shown for that choice. Route divergences into the same confirm-then-remediate handling used in the scroll-drift lesson. Apply the demotion rule symmetrically: two consecutive preview/outcome divergences for an item → demote that item's preview to `provisional`, or suppress the item from composition, until re-proven.

**R5 — "Always" is enforced as a composition gate.** An item for which no preview can be computed — no dry-run projection, no provisional-with-proof-handle — must fail composition loudly, or emit an explicit `preview.status: "unavailable"` marker that downstream rendering treats as an error state. Silent omission is how the invariant erodes.

**R6 — Previews stay local-first.** *(Completed from truncation.)* Preview computation, storage of the emitted artifact, and the parity-comparison loop (R4) must all run under the same always-on local-first posture the privacy-certification observation certifies: no preview text, proof handle, or outcome-comparison telemetry leaves the host as a side effect of composition. If an item's preview computation would require a remote call, that item is definitionally async and falls under R3 — the remote dependency becomes part of what the provisional preview discloses, not a hidden precondition of the "preview."

---

## Open Threads (verification pickups — none of these block the design above, all of them block *implementation*)

1. **Locate composition code.** Where newspaper.json is assembled in the kernel (`[redacted path] and whether a preview hook exists. `[unverified]`
2. **Item execution interface.** Confirm the execute/apply entry point's shape to decide between a `dry_run` flag and a `project()` sibling (R2). `[unverified]`
3. **Job-handle serializability.** Confirm background proof job handles can be embedded as `proof_ref` values in newspaper.json (R3). `[unverified]`
4. **Existing parity/telemetry surface.** Determine whether an outcome-recording channel already exists that R4's comparison loop can attach to, or whether one must be built. `[unverified]`
5. **Schema-of-record location.** Identify where the operator-item schema lives to enforce the "no stored `preview` field" rule from R1 (e.g., as a schema test or lint). `[unverified]`

## Closure rationale

The design question — *how should previews always be carried* — is answered completely and consistently with all four prior-art constraints: derived not stored (R1), single-path (R2), provisional-with-proof for async (R3), observationally enforced (R4), gate-enforced universality (R5), local-first (R6). What remains is repo verification, which is a pick-up task with filesystem access, not a research question. The line crystallizes here.

## References

Prior art (llm-wiki vault; read-only pointers supplied in the transition packet — the only citations this record can ground):
- `[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]` — Research Lesson: If drift is confirmed in the scroll behavior (basis for R2, R4)
- `[[sources/obs-2026-08-25-privacy-certification-posture-always-on-local-first-heartbea]]` — Observation: privacy-certification posture, always-on local-first (basis for R6)
- `[[sources/async-proof-pattern-for-long-drop-ins]]` — Prove long-running drop-ins with background jobs (basis for F3, R3)
- `[[sources/outcome-demotion-at-two-consecutive-failures]]` — Consecutive bad-execution cancellation (basis for R1, R4)

Repository paths: **none cited.** `[redacted path] was named in the line's mandate but never readable during this line's lifetime; all repo-dependent claims are marked `[unverified]` above and enumerated as Open Threads rather than asserted.
