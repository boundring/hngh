# Why does cadence/hour/16-remote-push.sh show wall=23.1s (later 28.6-40.8s) against a 0.0s median (x12+), is that latency a defect or expected gate-rerun work, and what disposition (fix or park) does the beat design support?

Status: crystallized 2026-09-14 from research line `fail-20260910-slow-unit-dropin-16-remote-push.sh`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260910-slow-unit-dropin-16-remote-push.sh.md.

# Research Line Crystallization (contracting → final record)

**Line:** Why does `cadence/hour/16-remote-push.sh` show wall=23.1s (later 28.6–40.8s) against a 0.0s median (x12+), is that latency a defect or expected gate-rerun work, and what disposition (fix or park) does the beat design support?
**Lifecycle:** expanding → contracting → **crystallized**
**Prior beat:** 2026-09-14 (wall_s: 173.0)

---

## 1. Verification status (stated up front)

I must be explicit: in this transition I have no execution access to the filesystem, and the prior beat's material shows the same limitation — the planned `ls`/`cat`/`grep` probes were drafted but no output was returned. Therefore:

- **Unverified:** the existence and contents of `/home/bricker/Projects/etc/hngh/cadence/hour/16-remote-push.sh`, any gate definitions under `cadence/`, and the current `research-lines.tsv` entry. These paths come from the line description, not from observed file contents.
- **Verified-by-line-description only:** the wall-time observations (0.0s median across ≥12 samples; spikes of 23.1s, then 28.6–40.8s).

No claim below rests on a file I have not seen unless flagged. Where the disposition depends on file contents, I mark the dependency explicitly.

## 2. Findings

**F1 — The bimodal wall-time signature indicates conditional work, not a constant defect. (High confidence, from the numbers alone.)**
A median of 0.0s across 12+ runs means the script's dominant path is effectively a no-op or a cheap check. Spikes of 23–41s on a minority of runs mean some condition — state dirtiness, a changed ref, a failed precondition — occasionally triggers heavy work. A uniformly slow script (network-bound push every run) would show a high median, not a zero one.

**F2 — The most plausible heavy path is gate re-execution, per the line's own framing. (Medium confidence; mechanism unverified.)**
The line hypothesis ("gate-rerun work") fits the signature: on most hours nothing has changed, so the push short-circuits; when the ledger or tree is dirty, the script re-runs a verification gate before or during the push, and that gate dominates wall time. Whether the gate runs *inside* the push script or is triggered by it cannot be determined without reading the script — **this is the single unverified fact the disposition hinges on.**

**F3 — The beat design's own prior art defines the defect boundary. (Confidence: as recorded in the vault pointers.)**
The read-only pointer `[[sources/long-gates-run-async-against-interjections]]` records a design principle: long verification gates should run asynchronously so that interjections (and, by extension, other beats) are not blocked. Applying it here yields a clean test:
- If `16-remote-push.sh` *is* the designated gate runner for this cadence slot, synchronous 23–41s execution is **expected work** — the wall time is the cost of evidence-gating, and the defect framing fails.
- If the push script is *supposed* to be a thin publisher and is synchronously absorbing gate work that belongs in an async lane, the spike is a **design deviation** per that principle — a real defect, but of placement, not of the gate itself.

**F4 — The evidence ledger does not yet support "defect." (High confidence as a methodological claim.)**
Per the evidence-gated disposition practice referenced in `[[sources/backlog-disposition-sweep-reduces-accepted-plans-by-half]]` and the sandbox-only constraint in `[[sources/debug-repro-sandboxes-only]]`, a fix committed without a reproduced mechanism would violate the ledger standard. The current evidence (timing stats without a profiled breakdown) is insufficient to distinguish F3's two branches.

## 3. Disposition and recommendations

**Disposition: PARK — with a single cheap instrumentation action, not a fix.**

The beat design supports this disposition on three grounds:

1. **Expected work is the leading hypothesis.** The 0.0s median plus conditional spikes is exactly what a correctly evidence-gated hourly push should look like. Absent proof that the gate is misplaced, "fixing" the latency would mean removing verification work — trading safety for a prettier wall number.
2. **The defect branch, if real, is architectural (gate placement), not algorithmic.** That class of change deserves its own expanding line with a sandboxed repro, not a drive-by patch inside a contracting line.
3. **Instrumentation converts this from open question to self-resolving monitor.** A one-line-per-phase timing log (check / gate / push) appended to the script's existing output would let the next N beats attribute the spike definitively at zero risk.

**Recommended actions, in order:**
- **R1 (do now, low risk):** Add phase-level timing to `cadence/hour/16-remote-push.sh` (unverified path — confirm first) so future spikes carry their own attribution. If the script already logs per-phase durations, this reduces to "read the existing logs on the next spike."
- **R2 (park):** Record the line as *expected gate-rerun work pending evidence to the contrary*. Re-open only if instrumented data shows the spike occurring on clean/no-change runs (which would refute F2) or if the synchronous gate demonstrably blocks interjections (which would activate the `long-gates-run-async` principle as a defect).
- **R3 (do not do):** Do not move the gate out of the script, add caching, or skip verification on this evidence base. Each would be an unevidenced change to a safety mechanism.

## 4. Open threads (for future lines)

- **T1:** Read `16-remote-push.sh` and the gate configuration under `cadence/`; confirm whether the gate runs in-process (expected work) or whether a thin publisher is absorbing async-lane work (defect). This was planned in the prior beat but never executed.
- **T2:** If T1 shows a placement defect, spawn a new line: "Move remote-push verification gate to async lane per long-gates-run-async principle," with a sandboxed repro per `debug-repro-sandboxes-only`.
- **T3:** After instrumentation lands, collect ≥2 attributed spike events and update this record's F2 from "plausible" to confirmed or refuted.
- **T4 (external, unverifiable here):** Whether 23–41s is a reasonable duration for the gate's actual workload (test suite size, network target) depends on the remote system, which I cannot inspect; that comparison must be made by an operator with access.

## References

Paths named by the research line / prior material (existence **not verified** in this transition):
- `/home/bricker/Projects/etc/hngh/cadence/hour/16-remote-push.sh` — subject script
- `/home/bricker/Projects/etc/hngh/cadence/` — cadence directory, gate definitions
- `research-lines.tsv` — line state ledger

Prior-art pointers (llm-wiki vault, read-only):
- `[[sources/long-gates-run-async-against-interjections]]` — defect boundary for F3/R2
- `[[sources/debug-repro-sandboxes-only]]` — constraint on any T2 repro
- `[[sources/backlog-disposition-sweep-reduces-accepted-plans-by-half]]` — evidence-gated disposition standard supporting park-over-fix
- `[[sources/SRC-2026-08-24-021]]` — Evidence Ledger design context

No external sources were consulted; all claims are grounded in the line's recorded observations and the vault pointers above, with verification gaps stated inline.
