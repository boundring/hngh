# What is the minimum viable set of automatable checks (T0/T1) that can be performed at ingest time to reduce the manual adjudication load for the R3 audit gate without compromising the false-permissive error bound?

Status: crystallized 2026-09-13 from research line `fail-20260913-What-is-the-minimum-viable-set-of-automa`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260913-What-is-the-minimum-viable-set-of-automa.md.

# Research Line — Crystallized Record (contracting → closed)

**Line:** What is the minimum viable set of automatable checks (T0/T1) performable at ingest time to reduce the manual adjudication load for the R3 audit gate without compromising the false-permissive error bound?
**Lifecycle:** expanding → contracting → **closed (this transition is the lasting record)**
**Continuity note:** The line has been in continuous motion on idle hosts; this transition crystallizes it rather than concluding a batch.

---

## 0. Grounding caveat (read first)

The prior beat (2026-09-13) planned a file-level exploration of `~/Projects/etc/hngh` and `hngh-automation` to ground recommendations, but the record **truncates at 4000 bytes mid-exploration — before any command output was captured**. No `ls`/`find`/`grep` results exist in the surviving material. The exploration step was never actually executed on this line.

Therefore: **no file paths inside either repository can be cited with confidence in this record.** The only paths asserted here are the two repository roots themselves, as named in the task framing and prior art. Everything below is conditional on repository structure that remains unverified, and where claims need verification, that is stated explicitly. This is recorded deliberately — the truncation of the grounding step is itself a finding (see F4).

---

## 1. Findings

**F1 — The research question is well-posed and has a principled answer independent of repository internals.**
The minimum viable check set is determined by a soundness direction, not by check count: an ingest-time check is safe to automate if and only if (a) its *pass* provably implies the property the R3 gate would otherwise adjudicate manually, or (b) its *failure* always escalates to manual adjudication rather than rejecting or silently mutating. Checks that satisfy (a) reduce load; checks that satisfy (b) preserve the error bound. A check that can auto-accept wrongly is the only kind that compromises the false-permissive bound. This is a design principle derived on this line; it is not yet tied to any verified implementation file.

**F2 — Asymmetric cost structure makes conservatism cheap.**
Auto-*rejecting* (or auto-escalating) a valid item increases adjudication load — a recoverable cost. Auto-*accepting* an invalid item is a false-permissive error — the bounded quantity. So the minimum viable set is exactly: **all checks whose pass-direction soundness can be demonstrated, plus escalation-on-anything-else.** Nothing else is required; nothing more is safe by default.

**F3 — Prior art establishes intent and tooling context, not implementation.**
The vault pointers confirm: (i) a *bounded delegation* framing exists ([[entities/bounded-delegation]], [[sources/SRC-2026-08-18-004]]), which is the governance envelope this line's checks must live inside; (ii) an overnight automation harness for `hngh-automation` was reported built, verified, and enabled ([[sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled]]); (iii) an hngh knowledge-base ingestion path into llm-wiki was observed ([[sources/obs-2026-08-19-hngh-knowledge-base-ingestion-in-llm-wiki]]). These are read-only pointers with unknown provenance dates; the underlying source documents were not readable from this line. Whether the harness already implements any T0/T1 checks is **unverified**.

**F4 — Process finding: grounding steps must checkpoint before truncation.**
The prior beat's record cut off mid-exploration at the 4000-byte truncation boundary, losing all command output. Any beat that intends to ground claims in repository files should persist incremental findings early (write results to `research-lines.tsv`-adjacent state or a scratch note *as they arrive*), not in a single terminal block. This affected this line directly and will affect any line that defers evidence capture to the end of a beat.

---

## 2. Recommendations

These are conditional on the repository layout being as implied; the file-level attachment of each recommendation is **open thread OT1**.

**R1 — Adopt the conservative-soundness criterion as the definition of "automatable."**
Codify: a T0/T1 check may auto-accept only with a written, reviewable argument that pass ⇒ R3-property. All other outcomes escalate. This turns "minimum viable set" from an empirical question into an auditable enumeration.

**R2 — Tier the minimum viable set as follows (principle-level; no verified file attachment):**

- **T0 (syntactic / integrity, all safe to automate under F1):**
  - Schema/format validation against the ingest contract; failure → reject-with-log, never repair-and-accept.
  - Hash/checksum integrity against declared provenance metadata.
  - Size/encoding/envelope sanity bounds.
  - Duplicate detection against an ingest ledger (exact-content match only; fuzzy matching is T1+ at minimum).
- **T1 (deterministic semantic, automatable only where pass-soundness is shown):**
  - Provenance signature / attestation verification against the bounded-delegation policy envelope (per [[entities/bounded-delegation]]).
  - Referential integrity against already-admitted corpus identifiers.
  - Policy allowlist/denylist screening (denylist hit → escalate, *not* silent drop, so the rejection path itself is auditable).
- **Explicitly excluded from automation at ingest:** anything involving judgment about content adequacy, novelty, or adversarial intent — these are what R3 exists to adjudicate, and automating their *accept* direction is precisely where false-permissive errors enter.

**R3 — Instrument the load-reduction claim before claiming it.**
The line's premise is adjudication-load reduction, but no baseline measurement of current R3 adjudication volume or false-permissive rate appears anywhere in the prior material. Before/without a measured baseline, "reduced load" and "bound preserved" are unfalsifiable. Recommendation: the harness (reported enabled per [[sources/obs-2026-08-25-...]]) should log per-item check outcomes and R3 dispositions so the bound can be monitored empirically. Whether such logging already exists is unverified.

**R4 — Make the error bound explicit and version-controlled.**
No definition of the false-permissive error bound (threshold, denominator, measurement window) appears in the prior material. The bound must be a named, inspectable constant with an owner, or "without compromising the bound" cannot be evaluated. Location within `hngh`/`hngh-automation`: unknown — OT1.

**R5 — Escalation is the default sink.**
Every T0/T1 outcome that is neither proven-pass nor proven-fail escalates to the existing R3 queue. This guarantees the automation can only ever *add* adjudication load, never subtract correctness — the property that makes the set "minimum viable" rather than "minimum risky."

---

## 3. Open threads

- **OT1 (blocking, carried from truncated beat):** Execute and *checkpoint* the repository exploration of `~/Projects/etc/hngh` and `hngh-automation` — locate ingest entry points, existing T0/T1 implementations, R3 gate trigger logic, and any error-bound definition. Attach R2's tiers to concrete files. This was the prior beat's plan; it produced no surviving output.
- **OT2:** Locate the actual definition (if any) of the false-permissive error bound; if absent, R4 becomes a proposal, not a description.
- **OT3:** Read the bounded-delegation source documents ([[sources/SRC-2026-08-18-004]]) to confirm T1 provenance checks fit the delegation envelope rather than inventing a parallel one.
- **OT4:** Baseline measurement of R3 adjudication volume and current false-permissive rate (R3 prerequisite).
- **OT5:** Determine whether the enabled overnight harness already performs any ingest-time checks, to avoid duplicating or conflicting with it.

---

## References

Repositories (roots cited as given in the task framing; internal structure unverified on this line):
- `~/Projects/etc/hngh` — hngh kernel repository (root asserted; no internal files verified)
- `hngh-automation` (path referenced in prior material; the 2026-09-13 beat assumed `~/Projects/etc/hngh-automation` — **unverified**)

Line state:
- `research-lines.tsv` (line state file; referenced by task framing)

Prior art (llm-wiki vault, read-only pointers; underlying documents not read on this line):
- [[entities/bounded-delegation]] — Bounded Delegation
- [[sources/SRC-2026-08-18-004]] — Bounded Delegation Tooling
- [[sources/obs-2026-08-19-hngh-knowledge-base-ingestion-in-llm-wiki]] — Observation: hngh knowledge-base ingestion in llm-wiki
- [[sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled]] — Observation: hngh-automation overnight harness built/verified/enabled

**Explicit non-claims:** No file paths inside either repository are cited, because none were verified — the prior beat's exploration truncated before producing output, and this transition has no live repository access. No external sources were consulted; where recommendations would normally rest on external literature (e.g., staged-validation or fail-closed gate patterns), they are instead derived from first principles on this line (F1/F2) and marked as such.
