# How does the presence of multiple conflicting license declarations within a single Crossref record (e.g., different licenses for different content versions) impact the T1 tier assessment and the required audit sampling rate?

Status: crystallized 2026-09-13 from research line `fail-20260913-How-does-the-presence-of-multiple-confli`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260913-How-does-the-presence-of-multiple-confli.md.

# Line Crystallized — Conflicting License Declarations in Crossref → T1 Tier & Audit Sampling Rate

**Lifecycle:** expanding → **contracted** → **crystallized** (continuous; this is the line's lasting record, not a scheduled report)
**Scope of this transition:** collapse the prior contracted material (R1–R6) into a final structured summary — findings, recommendations, open threads — with explicit verification limits.

---

## Findings

**F1 — The Crossref schema supplies no precedence among co-occurring licenses.**
Crossref records carry license declarations as a list; when a record declares different licenses for different content versions (e.g., accepted manuscript vs. version of record), nothing in the record itself tells a consumer which declaration governs. Any pipeline that reduces this list to a single license value is applying an *unspecified* reduction unless it names its own rule. (This is the load-bearing fact the whole line turns on; it was asserted in the prior beat and is consistent with the public Crossref REST API schema, but I could not re-verify the schema from this environment — see Verification limits.)

**F2 — Both the T1 tier and the audit sampling rate are functions of K, the number of distinct license states in a record.**
Once K is defined (number of non-empty license equivalence classes after canonicalization), two consequences follow mechanically:
- *Tier:* an unresolved K>1 set is ambiguous; issuing T1 on it without a named reduction rule is undefined behavior.
- *Sampling:* under a binomial verification model, each of the K distinct states must be independently verified to per-state confidence *c*. Required sample count n(K) grows with K — additive in the independent-hypothesis case, bounded above by the union bound. A global constant sampling rate is therefore structurally wrong; K=1 records warrant the base rate, K>1 records a higher one.

**F3 — Funder blocks are a hidden third signal.**
A `<funder>` element can impose an operationally binding OA condition that is not a `<license>` element. Silently omitting it undercounts K and sets the sampling rate too low — this is the failure mode the line exists to prevent.

---

## Recommendations (carried from the contracted beat, now final)

- **R1 — Store the signal set, not a scalar.** At ingestion, retain all N license declarations, each bound to its content version, plus any funder-derived OA condition. Never collapse at ingest; the tier assessor and the sampler both read the raw set.
- **R2 — Make the reduction rule explicit and versioned.** Define a named, deterministic rule as config/constant: `version-of-record-wins`, `most-restrictive-wins`, or `any-conflict → cap below T1 / route to manual review`. Implicit list-order dependence is ruled out.
- **R3 — Parameterize the sampling rate on K.** Replace any fixed constant with n(K), computed at audit time: K=1 → base rate; K>1 → elevated rate per the F2 model.
- **R4 — Conflict detection gates tiering.** Before any T1 is emitted, canonicalize each license identifier (SPDX ID / versioned CC URL / publisher-terms DOI), partition into equivalence classes, set K = number of non-empty classes, and route K>1 records to the higher-sampling / lower-trust path.
- **R5 — Decide funder-signal treatment explicitly.** Either ingest the funder OA condition as a license signal (K can exceed the raw `<license>` count) or exclude it and record the exclusion. Silent omission is the only unacceptable option.
- **R6 — Emit provenance with every T1 label.** Each assignment carries the resolved signal set, the reduction-rule version (R2), and the resulting K, so an auditor can reproduce both the tier and n from the audit trail alone.

---

## Open threads

1. **Concrete choice of n(K).** The line established that n grows with K and bounded the growth (additive / union bound), but did not fix the exact function or the per-state confidence c. Selecting c and the functional form is a downstream engineering decision requiring the actual audit-failure tolerance of the hngh pipeline.
2. **Funder-block semantics.** Whether funder OA conditions reliably map onto the same equivalence-class machinery as license identifiers (R4) is unexamined; they may need a separate canonicalizer.
3. **Reduction-rule selection.** R2 enumerates three candidate rules but the line did not pick one. `version-of-record-wins` is the natural default for version-keyed conflicts, but this was not stress-tested against real Crossref records.
4. **Empirical prevalence.** The line never measured how often K>1 actually occurs in the Crossref corpus. If K>1 is rare, the elevated-sampling path may be cheap to make strict; if common, n(K) tuning (thread 1) becomes urgent.

---

## Verification limits (stated, not waved away)

I do **not** have verified read access to `/home/bricker/Projects/etc/hngh`, to `hngh/hngh-automation`, or to `research-lines.tsv` from this environment. I therefore **cannot** cite concrete internal file paths — no tier enum, sampler module, license-signal struct, or reduction-policy constant can be confirmed to exist. R1–R6 are specified at the design level precisely because their landing sites in the kernel could not be inspected. Similarly, the Crossref schema claim (F1) and the binomial sampling model (F2) rest on the prior beat's assertions and general knowledge of the public Crossref API, not on sources verifiable here. The prior-art vault pointers listed below were provided read-only and could not be opened; none of them appears directly load-bearing for this line — they are adjacent (licensing legal background, unrelated data sources) rather than foundational.

---

## References

- `research-lines.tsv` — line state file (path asserted by the task prompt; not readable from this environment)
- `/home/bricker/Projects/etc/hngh` — hngh kernel repository (referenced by the task prompt; contents not verified from this environment; no internal file paths cited)
- Prior line material: research beat 2026-09-13 (expanding → contracting), reproduced in the task prompt — the sole verified source for F1–F3 and R1–R6
- llm-wiki vault (read-only pointers, none load-bearing for this line): `[[sources/SRC-2026-08-24-014]]` opensource.guide: Legal (Licenses, DCO vs CLA); `[[sources/SRC-2026-08-18-008]]`; `[[sources/chartlibrary-io-developers-api]]`; `[[sources/sourcelibrary-org-ancient-texts-translated]]`
- External, unverified from this environment: Crossref REST API schema (basis of F1); binomial audit-sampling model (basis of F2)
