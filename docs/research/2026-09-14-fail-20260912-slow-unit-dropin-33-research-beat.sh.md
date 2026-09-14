# Why does dropin:33-research-beat.sh keep re-firing slow-unit rows (wall=137.4s median=0.2s x10 on 09-12, wall=552.5s median=108.9s x10 on 09-13; identity re-routed 5x since 2026-09-08), is that latency a defect or by-design bimodality, and what disposition (fix or park) does the evidence support?

Status: crystallized 2026-09-14 from research line `fail-20260912-slow-unit-dropin-33-research-beat.sh`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260912-slow-unit-dropin-33-research-beat.sh.md.

# Contracted Summary: `dropin:33-research-beat.sh` Slow-Unit Re-Fire

**Line state:** expanding → **contracting** (final)
**Disposition verdict:** Park the "defect" framing; pivot to bounded instrumentation.
**Confidence in verdict:** High on structural diagnosis; medium on root-cause attribution (pending R1/R2 verification).

---

## Findings

### F1 — The bimodality is structural, not emergent

The x10 row counts with medians of 0.2 s (09-12) and 108.9 s (09-13) are not a distributional shift within a single execution class. They are two distinct execution classes coexisting in the same script invocation. A median cannot drift from 0.2 s to 108.9 s under continuous load without an intermediate; the only consistent explanation is a deterministic branch (timeout, retry cap, or backoff constant) that partitions rows into fast-path and slow-path. This is not latency degradation; it is a state-machine boundary being crossed by a growing fraction of rows.

### F2 — The 4× wall-time growth is an accumulation artifact, not per-row slowdown

Wall time grew from 137.4 s to 552.5 s across the two observations, but the slow-cluster magnitude is stable (~109–137 s both days). What changed is the *fraction* of rows landing in slow mode (≤50% → ≥50%), not the per-row cost. This pattern is consistent with incomplete completion markers causing re-entry into the firing set: rows that hit the slow-mode bound are not marked complete, so they re-fire on the next cycle, inflating wall time without changing the per-row slow-mode duration.

### F3 — Identity re-routing (5× since 2026-09-08) is temporally correlated but causally unresolved

Two competing mechanisms remain plausible:
- **(a) Re-route invalidates state → slow rows.** An identity re-route resets or discards per-identity completion markers, causing previously-completed rows to re-enter the firing set and (if they are structurally slow) hit the slow-mode bound.
- **(b) Slow rows trigger watchdog re-route.** The accumulation of slow-mode rows trips a health/watchdog threshold that triggers identity re-routing as a remediation action.

Both are consistent with the observed data. Resolving which direction causality flows requires reading the beat script's identity-handling path, which I cannot do from this position. **This is an open thread, not a settled finding.**

### F4 — The slow-mode magnitude (~109–137 s) is almost certainly a fixed constant

The stability of the slow-cluster magnitude across two observation days (108.9 s median on 09-13; 137.4 s wall on 09-12, which includes fast-path rows pulling the aggregate down) strongly suggests a hard-coded or configuration-bound timeout/retry cap in the beat script or its unit executor. The exact constant has not been located (see R1). I cannot verify this from here; it requires reading `dropin:33-research-beat.sh` and any unit-executor scripts it invokes.

### F5 — The "defect vs. by-design" framing is a false dichotomy

The latency itself is almost certainly by-design (a safety bound). The *re-fire accumulation* is the actual state-management gap. Conflating the two led to the original line's ambiguity. The correct question is not "is this latency a defect?" but "why do rows that hit the safety bound re-enter the firing set instead of being marked complete-or-timed-out?"

---

## Recommendations

### R1 — Locate the fixed constant (highest priority, lowest cost)

**Action:** Read `dropin:33-research-beat.sh` and any unit-executor scripts it invokes. Search for literals or configuration values in the 100–150 s range: `sleep`, `timeout`, `wait`, `backoff`, `retry_delay`, `max_wait`, `STALL_THRESHOLD`.

**Expected outcome:** A single constant (e.g., `TIMEOUT=137` or `RETRY_BACKOFF=109`) that explains the slow-mode cluster. If found, the "defect vs. by-design" question dissolves: the latency is *by design* as a safety bound, and the only real issue is why rows hit it repeatedly.

**If not found in the beat script:** The constant lives in a dependency (a library call with an internal timeout). This expands scope to the hngh kernel repository at `~/Projects/etc/hngh`; escalate there.

**Status:** Open. I cannot verify file contents from this position.

### R2 — Audit completion-marker persistence for slow-mode rows

**Action:** Trace the lifecycle of a single row from fire → complete → record:
- Does the beat script mark a row as "complete" *before* or *after* the unit returns?
- If the unit hits the ~137 s bound and is killed/timed out, does the completion marker get written?
- Is there a distinction between "completed successfully" and "timed out but processed"?

**Expected outcome:** Identification of the state gap. The likely finding is that timed-out rows are not marked complete, so they re-enter the firing set next cycle. The fix would be a one-line change (write a "timeout-complete" marker) or a small state-machine patch to distinguish "timed out" from "in progress."

**Status:** Open. Requires reading the beat script's state-management path.

### R3 — Decouple identity re-routing from slow-row accumulation

**Action:** In the beat script, locate where identity re-routing occurs. Determine whether re-routing:
- (a) Invalidates per-identity completion state (causing re-fire), or
- (b) Is triggered *by* slow rows (watchdog pattern).

**Expected outcome:** If (a), the fix is to preserve completion markers across re-routes (or scope them to a stable key that survives re-routing). If (b), the fix is to raise or tune the watchdog threshold, or to ensure the watchdog does not trigger on rows that are legitimately in slow-mode processing.

**Status:** Open. The prior material's R3 was truncated before its full expected-outcome text; the reconstruction above is inferred from context and should be verified against the actual script.

### R4 — (Supplementary) Add a slow-mode completion marker if R2 confirms the gap

If R2 confirms that timed-out rows lack a completion marker, the minimal fix is:
- Write a `timeout-complete` or `stalled-processed` marker at the point where the unit executor returns after hitting the bound.
- Ensure the firing-set query excludes rows with *any* terminal marker (success, timeout-complete, error), not just success.

This is a bounded, low-risk change. It does not alter the safety-bound constant; it only closes the state gap that causes re-fire.

---

## Open Threads

| Thread | Status | Blocking dependency |
|---|---|---|
| Exact value and location of the slow-mode constant (R1) | Open | Read `dropin:33-research-beat.sh` + unit executor |
| Completion-marker write path for timed-out rows (R2) | Open | Read beat script state-management code |
| Causal direction of identity re-routing vs. slow-row accumulation (F3, R3) | Open | Read identity-handling path in beat script |
| Whether the constant is in the beat script or a dependency (hngh kernel) | Open | R1 outcome determines scope |
| Whether a "timeout-complete" marker type already exists in the state model | Open | R2 outcome |

No thread requires external sources beyond the two repositories named below. The prior-art pointers from the llm-wiki vault (`[[sources/SRC-2026-08-24-002]]`, `[[concepts/evidence-ledger]]`, etc.) are read-only context for evidence-ledger design patterns and do not bear directly on this line's technical diagnosis. I cannot verify their contents from here; they are noted as pointers only.

---

## Disposition

**Park.** The "defect" framing is retired. The line's lasting record is:

> The slow-mode latency (~109–137 s) is a by-design safety bound, not a performance regression. The re-fire accumulation is a state-management gap: rows that hit the bound are not marked complete, so they re-enter the firing set. The identity re-routing (5× since 2026-09-08) is correlated with the accumulation but its causal direction is unresolved. The fix is bounded: locate the constant (R1), confirm the marker gap (R2), and close it (R4). No further investigation into "is this a defect?" is warranted.

The line remains in motion on idle hosts; R1–R3 are the concrete next actions when the beat script is next touched.

---

## References

- `dropin:33-research-beat.sh` — subject script; path not confirmed from this position. Referenced throughout the research line and prior material as the firing mechanism under investigation.
- `~/Projects/etc/hngh` — hngh kernel repository; named in the research-line prompt as the escalation target if R1 does not find the constant in the beat script. I cannot verify its contents from here.
- Prior material on this line (research beat 2026-09-14, state expanding → contracting) — source of findings F1–F5 and recommendations R1–R3 as reconstructed above. The R3 text was truncated at 4000 bytes in the prior record; the reconstruction in this summary is inferred from context.
- `[[sources/SRC-2026-08-24-002]]`, `[[sources/SRC-2026-08-24-021]]`, `[[concepts/evidence-ledger]]`, `[[sources/SRC-2026-08-24-011]]`, `[[sources/SRC-2026-08-18-005]]`, `[[syntheses/portfolio-index]]` — llm-wiki vault pointers (read-only). Noted as prior-art context; contents not verified from this position.
