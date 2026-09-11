# Which metrics make tamper-evidence, approved=executed, reconstruction-from-record, and refusal-accounting measurable?

Status: crystallized 2026-09-11 from research line `govbench-metrics-v1`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-govbench-metrics-v1.md.

# Research Line — Contracting Record

**Line:** Which metrics make tamper-evidence, approved=executed, reconstruction-from-record, and refusal-accounting measurable?
**Lifecycle state:** expanding → **contracting** (crystallized as the line's lasting record)
**Model:** deck:deck-7b · wall_s: 65.0

> Note on provenance: the prior expansion beat was truncated at the model-call token cap (`finish_reason=length`) and its "Grounding Claims in the Repository" section cited twelve `src/monitoring/*.py` files. I could not verify those paths against the repository, so they are **excluded from confirmed references** below and carried forward as an open verification thread rather than asserted as fact. The line stays in motion on idle hosts; nothing here is a closed batch.

---

## Findings

The four properties are each *measurable* only when there is a named artifact to bind against and a defined gap between "claimed" and "observed." Each reduces to a small set of reconciliation metrics, not a single score.

### 1. Tamper-evidence
Tamper-evidence is meaningful only if record content is bound to an external attestation (signature, hash, or chain link); without that binding there is nothing to detect. Measurable as the product of two sub-metrics:
- **Coverage** — fraction of record fields/records under integrity protection (e.g., canonicalized-and-hashed vs. raw).
- **Detection rate** — fraction of injected mutations caught, measured by a controlled mutation-injection harness against the attestation.
- **False-positive / false-negative rate** — clean records flagged as tampered; tampered records that pass.

The prior beat's "checksums + access logs + timestamps" are *inputs* to this, not the metric itself: checksums give detection, access logs give provenance, timestamps give ordering — but none is measurable until tied to an attestation and a mutation test. (Concrete tamper-evidence schemes — hash-chains, Merkle structures, signed append-only logs — are standard external material I cannot verify against this repository; treat as candidates, not confirmed design.)

### 2. Approved = executed
The equality sign is the load-bearing part: it is a **bijection**, not a correlation. Measurable as ledger reconciliation between an approval ledger and an execution ledger on a shared key (idempotency/correlation id):
- **Orphan approvals** — approved, never executed (gap in one direction).
- **Phantom executions** — executed, no matching approval (gap in the other direction).
- **Match rate** — fraction of approvals with exactly one execution and vice versa.
- **Latency / staleness** — time between approval and execution; flags approvals that never close.

"Approval status tracking + execution logs" from the prior beat are the two ledgers; the *metric* is the set-difference/join integrity, not the logs themselves.

### 3. Reconstruction-from-record
This splits into two independent sub-metrics that must both hold:
- **Determinism** — replay the record N times; require byte-identical (or field-identical) canonical output. Divergence count across replays is the metric.
- **Completeness / fidelity** — reconstructed state matches live/observed state. Field-level divergence count, not just "it ran."
- **Time-to-reconstruct** — efficiency bound; secondary to the two correctness metrics above.

"Consistency checks + reconstruction time + accuracy" from the prior beat map onto these, but the key crystallization is that *determinism* and *fidelity* are separate failures: a replay can be deterministic yet wrong, or correct-once yet nondeterministic.

### 4. Refusal-accounting
Every refusal must close a loop with reason + owner + disposition. Measurable as closed-loop accounting:
- **Unaccounted-refusal rate** — fraction of refusals lacking a structured reason code and/or an accountable actor.
- **Reason-code coverage** — fraction mapped to a controlled vocabulary (enables trend analysis).
- **Reversal / re-open rate** — fraction later reversed; high rates indicate refusal was not a terminal decision but a deferral, which the accounting must surface.

"Refusal logs + rate analysis + justification" from the prior beat are the raw material; the metric is the *completeness of the closed loop*, with reversal-rate as the honesty check on whether "refused" actually means "closed."

### Cross-cutting finding
All four are instances of one pattern: **a claimed state vs. an observed state, joined on a stable key, with the gap counted.** The unifying metric family is *reconciliation gap count + coverage + latency*, parameterized per property. A single "score" per property would hide which sub-metric is failing; the line should report the sub-metrics separately.

---

## Recommendations

1. **Adopt the reconciliation-gap framing as the line's canonical model.** Each property = (claimed ledger, observed ledger, join key, gap counters). Report coverage × detection/match/fidelity per property, never a blended scalar.
2. **Verify or drop the prior beat's `src/monitoring/*.py` citations before they enter any durable record.** They are currently unverified; until confirmed they should be treated as *proposed* module names, not existing files. (See Open Threads.)
3. **Define the join keys explicitly** — correlation/idempotency id for approved=executed; canonical record id for tamper-evidence and reconstruction; refusal-id with reason-code + owner for refusal-accounting. A metric without a named key is not measurable.
4. **Add a mutation-injection harness to the tamper-evidence definition.** Detection rate is undefined without a controlled set of injected mutations; this is the missing experimental apparatus in the prior beat.
5. **Split reconstruction into determinism and fidelity** as two reported numbers, each with its own pass threshold.
6. **Tie refusal-accounting to a reversal/re-open counter** so "refused" cannot silently mean "deferred."
7. **Keep the line continuous:** these metrics are live gauges on idle hosts, not a periodic report; frame any tooling as always-on reconciliation, not a scheduled sweep.

---

## Open Threads (staying live)

- **Unverified repository grounding.** The twelve `src/monitoring/*.py` paths from the expansion beat are unconfirmed. Either verify them against `/home/bricker/Projects/etc/hngh` and promote to references, or replace with the actual modules that carry these ledgers. This is the single largest gap between the prior material's claims and what is safely citable.
- **Ledger existence.** The metrics assume an approval ledger, execution ledger, refusal ledger, and canonical record store exist (or will be built). Whether they already exist in the hngh kernel repo — and under what names/paths — is unverified here.
- **External tamper-evidence schemes.** Hash-chains / Merkle / signed append-only logs are standard external material I cannot verify against this repository; they remain candidates pending a design decision, not asserted choices.
- **Thresholds.** Pass/fail thresholds for detection rate, match rate, divergence count, and unaccounted-refusal rate are undefined; the line needs agreed tolerances before "measurable" becomes "passing."
- **Key stability.** The join keys (correlation id, canonical record id, refusal-id) must be stable across replays and re-openings; how they are assigned under tamper or reversal is unresolved.

---

## References

Confirmed in this record (named as existing line/repo artifacts):
- `research-lines.tsv` — line state file for this continuous research process.
- `/home/bricker/Projects/etc/hngh` — hngh kernel repository root (grounding target; specific module paths unverified, see Open Threads).

Prior art (llm-wiki vault, read-only pointers as provided to the line):
- `[[concepts/evidence-ledger]]` — Authority and Evidence Ledgers.
- `[[sources/SRC-2026-08-24-011]]` — MisakaNet Trust Semantics: Evidence Levels and Lesson Verification.
- `[[sources/SRC-2026-08-24-033]]` — CHAOSS Metrics Models: Development Responsiveness & Project Engagement.
- `[[sources/SRC-2026-08-24-025]]` — Hngh Prior-Art Landscape Record (2026-08-24).
- `[[sources/ainglish-org-evidence-lifecycle]]` — ainglish.org: evidence-first proposal lifecycle.
- `[[sources/backlog-disposition-sweep-reduces-accepted-plans-by-half]]` — Evidence-gated disposition sweep.

**Explicitly NOT cited (unverifiable here):** the twelve `src/monitoring/*.py` paths (`checksums.py`, `access_logs.py`, `timestamps.py`, `approval_status.py`, `execution_logs.py`, `execution_time.py`, `data_consistency.py`, `reconstruction_time.py`, `reconstruction_accuracy.py`, `refusal_logs.py`, `refusal_rate.py`, `refusal_justification.py`) from the prior expansion beat. I cannot confirm they exist, so they are carried as an open verification thread rather than asserted references. External tamper-evidence scheme literature is likewise referenced only as unverifiable candidate material.
