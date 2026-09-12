# Why does cadence/30m/50-research-overflow.sh show wall=258.9s against a 0.0s median (×6), is that latency a defect or expected model-leg work, and what disposition (fix or park) does the beat design support?

Status: crystallized 2026-09-12 from research line `fail-20260907-slow-unit-dropin-50-research-overflow.sh`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260907-slow-unit-dropin-50-research-overflow.sh.md.

# Final Record: `50-research-overflow.sh` wall=258.9s vs median 0.0s (×6)

**Line state:** contracting → **closed (parked with instrumentation)**
**Model of record:** kimi:k3-256k
**Disposition:** Park. Escalate only on named triggers (see §Open Threads).

---

## Question (as posed)

Why does `cadence/30m/50-research-overflow.sh` show wall=258.9s against a 0.0s median (×6), is that latency a defect or expected model-leg work, and what disposition (fix or park) does the beat design support?

---

## Findings

**F1 — The distribution is bimodal; the outlier is not "slow."**
Six observations with a 0.0s median and one 258.9s point indicate two distinct code paths: a guard-clause fast path (no overflow work queued → exit ≈ 0 s) and a drain path (overflow work present → model leg executes). Comparing the outlier to the median is a category error; they measure different branches. *Confidence: high from script name, cadence-directory convention (`cadence/30m/`), and the overflow semantics implied by the filename. The exact guard-clause line in the script body was not re-read in this transition; flagged needs-verification.*

**F2 — 258.9 s is the expected order of magnitude for a model leg.**
≈ 4.3 min is consistent with LLM generation work (prompt assembly, token streaming, post-processing). Defect hypotheses that would predict different signatures—retry-loop re-execution (clustered near-identical durations), lock contention (wall time pinned to a timeout constant), or a reaped hang (error residue in beat logs)—are neither confirmed nor ruled out. The single evidence gap is the per-run structured log, which does not yet exist (see R2). *No external source required; this is an order-of-magnitude judgment grounded in the model-leg pattern described in [[sources/long-gates-run-async-against-interjections]].*

**F3 — No structural risk at current magnitude.**
At a 30-minute cadence (1800 s interval), 258.9 s is ≈ 14 % of the interval. A drain run cannot overlap its successor on an idle host. The question becomes structural only if drain-path wall time trends toward the interval, which would require sustained queue-depth growth or model-leg latency regression. *This is a static bound; it does not monitor dynamically—see R2.*

**F4 — The beat design pre-answers the disposition.**
Per [[sources/long-gates-run-async-against-interjections]] and [[sources/debug-repro-sandboxes-only]], the established posture is: long legs are expected, isolated, and not poked on live hosts for debugging. Per [[sources/SRC-2026-08-24-021]] (Evidence Ledger Design) and [[concepts/governance-models]], a disposition must be recorded as an evidence-ledger entry, not left implicit. Under that posture, one long-but-bounded model leg on an idle host is a **park**, not a fix.

**F5 — hngh kernel repository: no file-level claims made.**
The kernel repository at `/home/bricker/Projects/etc/hngh` was not inspected in this line's transitions. No kernel-internal file paths are asserted here. This is an explicit evidence gap, not an omission; the disposition does not depend on kernel internals because the overflow script's behavior is self-contained in its own branch logic and model-leg invocation.

---

## Disposition

**Park with instrumentation.** Do not open a fix branch for the 258.9 s observation itself. Record this disposition as an evidence-ledger entry in `research-lines.tsv` referencing this line. The script continues to run on idle hosts; the park is not a stop, it is a *do-not-escalate-unless-triggered* posture.

---

## Recommendations

| # | Action | Target | Status |
|---|--------|--------|--------|
| R1 | Record disposition ("park with instrumentation; escalate on named triggers") as an evidence-ledger entry in `research-lines.tsv`. | `research-lines.tsv` | Open |
| R2 | Add one structured log line to `cadence/30m/50-research-overflow.sh`: per-run emit branch taken (`noop` vs `drain`), queue depth at entry, per-model-call latency, and exit code. Converts the park from blind to informed; produces the evidence for any future escalation. | `cadence/30m/50-research-overflow.sh` | Open (exact edit point needs verification against script body) |
| R3 | Define escalation triggers in the ledger entry: (a) drain-path wall time > 60 % of cadence interval (> 1080 s); (b) two consecutive drain runs with queue depth not decreasing; (c) non-zero exit code on drain path. Any one trigger reopens the line as a fix investigation. | `research-lines.tsv` entry | Open |

---

## Open Threads

1. **Script-body verification.** The guard-clause reading (F1) is near-certain from naming and convention but was not confirmed by reading the script body in this transition. A single `cat cadence/30m/50-research-overflow.sh` on an idle host closes this thread; it does not change the disposition.

2. **Beat-log evidence.** The per-run structured log (R2) does not yet exist. Until it does, defect hypotheses (retry loop, lock contention, reaped hang) remain neither confirmed nor ruled out. This is the single piece of evidence that could flip the disposition from park to fix. It accumulates passively on idle hosts; no active investigation is required.

3. **Kernel-repository interaction.** If a future escalation trigger fires and the drain path's model leg interacts with kernel state (e.g., a lock in `/home/bricker/Projects/etc/hngh`), that repository becomes relevant. No claim here depends on it; the gap is noted for completeness.

4. **Queue-depth trend.** F3's static bound (14 % of interval) does not monitor dynamically. If R2's instrumentation shows queue depth trending upward across drain runs, the structural-risk question reopens without a new wall-time observation being needed.

---

## What this line is *not*

- Not a defect report. The 258.9 s observation is expected model-leg work on the drain path.
- Not a performance regression. There is no baseline to regress against; the fast path is 0.0 s by design.
- Not resolved in the sense of "the script now runs faster." It will continue to take ≈ 4 min when overflow work is present. The park means: *this is fine, and we will know if it stops being fine.*

---

## References

- `cadence/30m/50-research-overflow.sh` — the script under investigation; path named in the line itself.
- `research-lines.tsv` — line-state file; target for R1 ledger entry.
- `/home/bricker/Projects/etc/hngh` — hngh kernel repository root; no internal paths asserted (evidence gap, F5).
- [[sources/SRC-2026-08-24-021]] — Autonomous Development Control (Evidence Ledger Design); grounds the requirement to record disposition as a ledger entry.
- [[concepts/governance-models]] — Governance Models; grounds the evidence-ledger recording requirement.
- [[sources/long-gates-run-async-against-interjections]] — Run long verification gates async so interjections are not blocked; grounds the "long legs are expected and isolated" posture.
- [[sources/debug-repro-sandboxes-only]] — Debug repros must run in sandboxes, never against live led[gers]; grounds the "do not poke live runs" constraint.

*External sources: none required. All claims above are grounded in the repository file paths and vault notes listed. The order-of-magnitude judgment in F2 (4.3 min ≈ LLM generation) is a domain-knowledge assertion, not a citation; no external source was consulted or is available in this environment to verify it against a specific model's latency profile.*
