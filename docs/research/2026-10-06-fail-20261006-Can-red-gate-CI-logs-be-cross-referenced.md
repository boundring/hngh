# Can red-gate CI logs be cross-referenced against `cadence/subhour/01-evolve-ui.sh` tick timestamps to empirically confirm the phase-alignment hypothesis (O4) and rule out a third-writer confounder before R1/R2 land?

Status: crystallized 2026-10-06 from research line `fail-20261006-Can-red-gate-CI-logs-be-cross-referenced`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20261006-Can-red-gate-CI-logs-be-cross-referenced.md.

# Crystallization Record — Research Line (Final Summary)

**Line:** Can red-gate CI logs be cross-referenced against `cadence/subhour/01-evolve-ui.sh` tick timestamps to empirically confirm the phase-alignment hypothesis (O4) and rule out a third-writer confounder before R1/R2 land?
**Terminal state:** contracting → crystallized
**Verdict on O4:** **Unconfirmed.** The line closes without an executed cross-reference. Its lasting contribution is a validated *methodology and preconditions* (R1–R3), not an empirical result.

---

## 1. What this line established (Findings)

**F1 — Timestamp correlation is not writer attribution.**
A worker's scratch-store path collides across wakes (see References: `obs-2026-08-26-hngh-worker-wake-scratch-store-path-collides-across-wakes`). Consequently, a red-gate event that is tick-aligned in time may have been written by a *second wake of the same cadence script* rather than by the evolve tick itself. A naive phase histogram φ = (t − t₀) mod T over unattributed events reproduces the O4 signature even when O4 is false. **Writer attribution is a hard precondition for the cross-reference, not a refinement.**

**F2 — The red-gate verdict predicate may not be single-surface.**
Per the vault lesson `verdict-rule-drift-two-surfaces`, a shared verdict rule has previously drifted across two surfaces, producing a false confirmation. "Red-gate event" as harvested from CI logs and "red-gate event" as the O4 hypothesis was formulated may therefore be different event classes. Cross-referencing timestamps before normalizing the predicate risks confirming O4 against mislabeled ground truth.

**F3 — Execution discipline for the verification job.**
Two standing lessons govern how the cross-reference must run: debug/repro work runs in sandboxes, never against live ledgers (`debug-repro-sandboxes-only`); long verification gates run async so interjections cannot corrupt them (`long-gates-run-async-against-interjections`).

**F4 — Proceed-as-if-confirmed is a recorded failure mode on this line's exact shape.**
`LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha` and `LES-fail-20260915-If-R1-confirms-1-surviving-class-on-1-ho` both record cases where confirmation posture preceded the controls that would have falsified it. This line's R1/R2 ordering is a direct application of those lessons.

## 2. Recommendations (the line's durable output)

**R1 — Writer-attribution gate before any phase computation.**
Extract a writer-identifying field from each red-gate event and from each tick record; filter to matching writer IDs; *only then* compute the phase histogram. Requires reading `cadence/subhour/01-evolve-ui.sh` to identify what marker the tick-emission mechanism writes (PID, wake ID, journal unit, or ledger marker). Without this, the histogram is uninterpretable and risks confirming O4 against a third-writer artifact.

**R2 — Verdict-predicate normalization before cross-referencing.**
Extract the red-gate pass/fail predicate from both the CI-side configuration and the ledger-side implementation in the hngh kernel repository; verify equivalence or explicitly document divergence and downgrade any result to partial confirmation.

**R3 — Read-only, async, sandboxed job structure.**
The cross-reference job must (a) run against copies/snapshots of CI logs and ledger data, never live ledgers; (b) run asynchronously; (c) emit its intermediate artifacts (writer-ID join table, predicate-comparison result) as inspectable outputs so a reviewer can audit the preconditions before trusting the phase histogram.

## 3. Open threads (handoff to the next line)

1. **O4 is empirically open.** No tick-timestamp cross-reference was executed during this line's lifetime. R1–R3 are specified but not implemented.
2. **Writer field unidentified.** The exact marker `cadence/subhour/01-evolve-ui.sh` emits to attribute its own execution has not been read from disk in any transition of this line. This is the first blocking read for whoever picks up the thread.
3. **CI-side predicate path unknown.** The red-gate CI configuration path in this repository was never resolved; the ledger-side predicate location in the hngh kernel repository was redacted in prior material and remains unresolved.
4. **Predicate equivalence unverified.** Even once both surfaces are located, the F2 comparison has not been performed.
5. **Join key undefined.** The common key linking CI-log events to tick records (beyond raw timestamps, which F1 shows is insufficient) has not been specified.

## 4. Honest limitations of this record

- This transition ran **without filesystem access**. I cannot confirm that `cadence/subhour/01-evolve-ui.sh` exists at that path, nor enumerate the contents of `[redacted path] Both paths are cited because the line definition and prior material name them, not because I verified them on disk.
- The vault notes cited below are referenced as read-only pointers from prior material; their titles/slugs are as given, and I have not re-read their contents in this transition.
- No claim in this record rests on external sources; where a claim would require one (e.g., specifics of CI log formats), none is made.

## References

- `cadence/subhour/01-evolve-ui.sh` — cadence tick script; named by the research line itself; existence on disk unverified in this transition.
- `[redacted path] — hngh kernel repository; location of the ledger-side red-gate predicate (exact internal path unresolved).
- llm-wiki vault (read-only pointers):
  - `[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]`
  - `[[sources/LES-fail-20260915-If-R1-confirms-1-surviving-class-on-1-ho]]`
  - `[[sources/debug-repro-sandboxes-only]]`
  - `[[sources/long-gates-run-async-against-interjections]]`
  - `[[sources/obs-2026-08-26-hngh-worker-wake-scratch-store-path-collides-across-wakes]]`
  - `[[sources/verdict-rule-drift-two-surfaces]]`

**Closing note:** This line contracts in the correct posture. O4 remains a live, falsifiable hypothesis with its falsification path now fully specified. The next transition on this thread should begin at Open Thread 2 (read the tick script), not at the phase histogram.
