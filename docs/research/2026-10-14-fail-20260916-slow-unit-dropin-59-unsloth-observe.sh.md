# Why did dropin:59-unsloth-observe.sh wall=30.4s vs median=0.1s x3 fire slow-unit (2026-09-16) — fixed: the outlier predates both later bounds (2026-09-23 probe_400 guaranteed-400 bounding 68539580: the old 150k-pair body FIT the 262144 context and got GPU-processed ~4.4min; 2026-09-24 1800s self-gate stamp: skip-exit ~0.003s is the median); post-fix real walls 0.5-12.1s, no re-occurrence since; the residual bimodal real-run class (status call + optional 400-probe, two chained 10s urllib timeouts, worst case ~20.6s) is inside the slow-units.py design envelope (22s, a7e62ae8, suite 13/13 incl test_unsloth_observe_in_envelope_never_flagged / test_unsloth_observe_over_envelope_flagged) — only a >22s wall re-fires the identity

Status: crystallized 2026-10-14 from research line `fail-20260916-slow-unit-dropin-59-unsloth-observe.sh`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260916-slow-unit-dropin-59-unsloth-observe.sh.md.

# Research line crystallization — dropin:59-unsloth-observe.sh slow-unit identity

_line state: contracting → crystallized. This is the lasting record for this line._

**Access caveat (binding for everything below):** this session has no live filesystem or git access. Every path, commit ID, timestamp, and test name cited comes from the recorded line state (`research-lines.tsv`) and prior beats, not from re-verification. Where a claim cannot be grounded in that record, it is explicitly marked **unverified**. The only path I cite with full confidence is the hngh kernel repository root given in the task: `[redacted path]

---

## 1. Identity and timeline

**Research question:** Why did `dropin:59-unsloth-observe.sh` record wall=30.4s against median=0.1s (×3 slow-unit ratio) on 2026-09-16?

**Answer (closed):** The 30.4s outlier was a *throughput-class* event that predates both bounding changes. Its mechanism, per bounding probe `68539580` (2026-09-23): the pre-fix 150k-pair request body *fit* the 262144-token model context, so it was genuinely GPU-processed for ~4.4 minutes rather than being rejected. After the `probe_400` change (guaranteed-400 probe body) and the 1800s self-gate stamp (2026-09-24), the unit's cost profile changed class entirely.

**Post-fix evidence:** real walls 0.5–12.1s; skip-exit ~0.003s is the true median; no slow-unit re-fire since 2026-09-24.

---

## 2. Findings (crystallized)

**F1 — The fix worked by class conversion, not by speedup.**
The unit moved from throughput-class (wall ∝ input size × model speed; unboundable by any wall-time envelope) to latency-class (wall ∝ chained calls × timeout constant + fixed overhead; arithmetically boundable). Post-fix worst case: 2 chained calls × 10s urllib timeouts + ~0.6s overhead ≈ **20.6s**.

**F2 — The 22s envelope holds with margin.**
The bound 20.6s < 22s sits inside the `slow-units.py` design envelope (commit a7e62ae8 per record). Suite state at last record: 13/13, including `test_unsloth_observe_in_envelope_never_flagged` and `test_unsloth_observe_over_envelope_flagged`, which pin the detector's behavior at both sides of the boundary.

**F3 — The identity re-fire condition is now crisp and singular.**
Only a real wall >22s re-fires the identity. The original GPU-processing mechanism cannot recur while the 400-probe body and self-gate remain in place, because a guaranteed-400 response carries no model compute.

**F4 — Residual unverified risk: DNS resolution.**
In CPython, `urllib.request.urlopen`'s `timeout` governs connect and read but may not bound `getaddrinfo`. **Unverified against the deployed interpreter.** If true in production, a DNS stall is the one mechanism that could exceed 22s with zero code change.

**F5 — The durable asset is the closure pattern, not the fix.**
*Bound the class, then pin the bound.* Any slow-unit identity that can be converted from throughput-class to latency-class can be closed the same way, and its closure can be made falsifiable by a single arithmetic inequality.

---

## 3. Recommendations (standing, for hngh/hngh-automation maintainers)

- **R1 — Pin the invariant, not just the detector.** Add a budget test that parses the timeout constants and chained-call count out of the dropin and fails if `n_calls × timeout_s + overhead > 22s`. This converts silent drift (e.g. a timeout bump to 15s → worst case ~30.6s → re-fire) into a test failure.
- **R2 — Colocate the envelope with the edit site.** Header comment in the dropin: the inequality, the current constants, and a pointer to `slow-units.py` / a7e62ae8. Today the envelope is enforced three files away from where it can be broken.
- **R3 — Resolve F4 empirically or accept it formally.** Run a blackholed/unresolvable-hostname probe against the production Python and measure wall. If unbounded: either bound resolution explicitly, or record DNS-stall as an accepted re-fire vector in `research-lines.tsv`.
- **R4 — Generalize.** For every future slow-unit identity: classify throughput vs latency first; throughput-class closure requires bounding input before the expensive call; latency-class closure requires a budget test per R1.

---

## 4. Open threads (carried, low priority)

1. **F4/DNS** — the only open technical risk; see R3.
2. **R1 budget test** — not yet implemented in the record; the suite pins detector behavior, not the arithmetic.
3. **No re-occurrence monitoring** — passive; the 2026-09-24→present clean streak is the evidence, and any >22s wall will surface itself via the existing detector. No action needed.

The line is otherwise complete: question answered, fix verified by absence of re-fire, residual risk enumerated and bounded.

---

## 5. Claims requiring external verification (not asserted)

- DNS/`getaddrinfo` timeout behavior under the specific deployed CPython version (F4/R3).
- Exact on-disk locations of `dropin:59-unsloth-observe.sh` and `slow-units.py` within the repository trees (the `dropin:` prefix is a detector label; the underlying file path is not in the record).
- That commits `68539580` and `a7e62ae8` remain at the recorded content — cited from line state, not re-inspected.

---

## References

- `[redacted path] — hngh kernel repository root (path given in task; cited with confidence).
- `research-lines.tsv` — line state file (this repository; location as given in task).
- `dropin:59-unsloth-observe.sh` — the unit under study (exact path unverified; referenced via detector label).
- `slow-units.py` — slow-unit detector; envelope 22s; commit `a7e62ae8`; tests `test_unsloth_observe_in_envelope_never_flagged`, `test_unsloth_observe_over_envelope_flagged` (all per line record).
- Commit `68539580` — 2026-09-23 probe_400 bounding probe establishing the ~4.4min GPU-processing mechanism.
- llm-wiki vault prior art (read-only pointers): `sources/LES-fail-20260915-If-R1-confirms-1-surviving-class-on-1-ho`, `concepts/billion-context-tuning`, `concepts/context-distillation`, `sources/SRC-2026-08-24-002` (CaMeL), `sources/SRC-2026-08-24-021` (Evidence Ledger Design), `sources/obs-2026-08-24-omp-context-via-billion-context-proxy-hngh-attestation-desig`.

**Line status: crystallized. Re-open only on a >22s wall or on F4 resolving to unbounded DNS.**
