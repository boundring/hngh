# What audit sampling and uncertainty tiering should gate OpenAlex/Crossref OA-status fields before they are trusted to enforce the R3 two-class license split at ingest?

Status: crystallized 2026-09-12 from research line `fail-20260912-What-audit-sampling-and-uncertainty-tier`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260912-What-audit-sampling-and-uncertainty-tier.md.

# Final Structured Summary: Audit Sampling and Uncertainty Tiering for OpenAlex/Crossref OA-Status Fields in the R3 Two-Class License Split

## Line Question
What audit sampling and uncertainty tiering should gate OpenAlex/Crossref OA-status fields before they are trusted to enforce the R3 two-class license split at ingest?

## Lifecycle State
Contracting → Final Record. This is the crystallized, lasting record of the line. The prior expansion beat (2026-09-12) truncated without usable findings; this contraction rests on the line question itself, general properties of OpenAlex/Crossref OA metadata, and the prior-art vault pointers. **No kernel file paths are asserted** because I could not inspect `/home/bricker/Projects/etc/hngh` or hngh-automation during this transition. Implementation-specific details are marked as hooks to be located, not citations.

## Findings

### F1 — OA-status fields are access signals, not license signals
OpenAlex `is_oa` / `oa_status` (gold, green, hybrid, bronze, closed) and Crossref presence/absence of a `license` array describe *access* to content, not the *legal terms* under which it may be reused. Green and bronze OA in particular assert availability via a repository copy that typically carries no machine-readable reuse license at all. Treating `is_oa = true` as license-class evidence would systematically misclassify items into the open class without redistributability rights. This is a structural property of the metadata, not an empirical claim requiring verification against a specific dataset version.

### F2 — The R3 two-class split requires asymmetric error handling
The two-class split (open vs. restricted) has fundamentally asymmetric failure modes:
- **False-permissive** (restricted item promoted to open): creates license liability, potential legal exposure, and violation of the integrity contract for downstream consumers who assume redistributability.
- **False-restrictive** (open item kept in restricted): degrades utility but creates no legal liability; the item remains safely available under conservative terms.

Any gating mechanism must be designed so that the false-permissive rate is tightly bounded, while the false-restrictive rate can be tolerated at higher levels. This asymmetry drives every subsequent design choice (tiering, disagreement rule, audit threshold).

### F3 — Aggregator-relayed license fields are weaker than primary sources
OpenAlex `best_oa_location.license` and per-location `locations[].license` entries are relayed from upstream sources (publisher pages, repository metadata, Crossref) through at least one aggregation layer. They can lag, be misparsed, or reflect a different content version than the one being ingested. They are not authoritative in isolation but are useful as corroborating evidence when they agree with a stronger source.

### F4 — Disagreement between sources is a first-class failure mode
When OpenAlex and Crossref disagree on license status (e.g., OpenAlex reports green OA, Crossref reports no license array), the conflict itself is diagnostic: it indicates at least one source is stale, misparsed, or describing a different version. The safe resolution is to take the *less permissive* reading and flag for audit, never to max-merge toward permissiveness.

## Recommendations

### R1 — OA-status fields must never directly flip the license class
**Rule:** No OA-status field (`is_oa`, `oa_status`, Crossref presence/absence of a license array) may, alone, promote an item from the restricted class to the open class in the R3 split. Default to the conservative (restricted) class; promotion requires positive license evidence meeting at least T1 tier (see R2). Demotion from open to restricted requires no evidence — it is the safe default.

This rule is structural: it follows directly from F1 and F2. It does not depend on any specific dataset version or kernel implementation.

### R2 — Four-tier uncertainty ladder for license evidence
| Tier | Source | Sufficient for promotion? | Notes |
|------|--------|--------------------------|-------|
| **T0** | License URL/SPDX identifier retrieved from the actual fulltext or publisher landing page for the exact version being ingested | Yes, directly | Authoritative. Requires live fetch; expensive. |
| **T1** | Crossref `license` array entry with a recognized license URL *and* a `content-version` / date window covering the item's publication state | Yes, after spot audit (R3) | Strong. Machine-readable but relayed through Crossref. |
| **T2** | OpenAlex `best_oa_location.license` or any `locations[].license` | Only if it agrees with T1 or passes stratum gate (R3) | Aggregator-relayed; corroborating only. |
| **T3** | Bare OA-status fields (`is_oa`, `oa_status`, Crossref presence/absence of license array with no parseable URL) | Never promotes | Contributes only to triage priority and audit sampling weight. |

**Disagreement rule:** When sources conflict, the *less permissive* tier wins, and the item is flagged for the audit queue. Never max-merge toward permissiveness. This is the single most dangerous failure mode for a license split (F2).

### R3 — Stratified audit sampling gate, per ingest batch
- **Stratification:** Sample by (source field, tier, publisher/venue if cheaply available). The stratum structure ensures that a systematically broken source field does not hide inside an overall acceptable error rate.
- **Starting sample size:** n ≈ 59 per stratum. Rationale: sufficient to detect a true false-permissive error rate ≥5% with ~95% confidence under a zero-finds-in-sample rule (binomial approximation, simple random sampling). *This number is a starting parameter, not a verified theorem; I have not checked it against a statistics text in this transition. Treat it as a tunable initial value to be validated against the actual error distribution once early batches are audited.*
- **Audit procedure:** (1) Automatable checks first — URL resolves, SPDX string recognized, license text matches expected terms. (2) Manual adjudication for the remainder. Audit = human or deterministic re-check of the license URL against the live landing page/PDF.
- **Gate:** A source field earns promotion rights for a batch only if its measured *false-permissive* rate in sample is at or below threshold. Recommended starting threshold: **≤1–2%**. The asymmetry matters: false-permissive errors create license liability; false-restrictive errors only coarsen availability (F2).
- **Failure action:** If a stratum exceeds the threshold, that source field loses promotion rights for the batch. Items relying on it remain in the restricted class and are queued for manual review. The gate resets per batch; it does not permanently blacklist a source field unless the failure is systematic across multiple consecutive batches.

### R4 — Triage priority from T3 fields
T3 fields (bare OA-status) never promote, but they inform *where to look next*. An item with `oa_status = gold` and no T1/T2 evidence is a higher-priority audit target than one with `oa_status = closed`. This does not change the class assignment; it only orders the audit queue.

### R5 — Version pinning for license evidence
License evidence must be tied to the specific content version being ingested (e.g., accepted manuscript vs. publisher PDF vs. repository copy). A T1 Crossref license entry that applies to `content-version: published` does not cover an item ingested as `content-version: accepted`. The tier assignment in R2 includes this check; if the version window does not cover the ingested state, the evidence drops one tier (T1 → T2) or is insufficient (T2 → T3).

## Open Threads

1. **Kernel implementation location.** The gating logic (tier assignment, disagreement resolution, audit queue management, batch gate enforcement) must live somewhere in `/home/bricker/Projects/etc/hngh` or hngh-automation. I could not inspect these repositories during this transition. **Hook:** Locate the ingest pipeline's license-class assignment step and confirm that R1–R5 are implemented as a pre-enforcement gate, not a post-hoc annotation.

2. **Empirical validation of the n ≈ 59 sample size.** The binomial approximation assumes a worst-case error rate near the threshold. If the actual false-permissive rate is lower (e.g., <1%), a smaller sample may suffice; if higher, a larger sample or stricter gate is needed. **Hook:** After the first 3–5 audit batches, compute the observed per-stratum error rates and recalibrate n and the threshold.

3. **Crossref `license` array coverage.** The T1 tier depends on Crossref providing a parseable license URL with a content-version window. Coverage varies by publisher; some publishers do not populate this field at all. **Hook:** Measure the fraction of ingested items for which T1 evidence is available, stratified by publisher/venue. If coverage is below ~60%, the system will default heavily to restricted class and the audit queue will be dominated by T2/T3 items.

4. **OpenAlex `locations[].license` reliability.** The T2 tier assumes OpenAlex relays license information from a traceable upstream source. I have not verified, in this transition, how often OpenAlex's license fields are populated vs. null, or how frequently they disagree with Crossref for the same item. **Hook:** Run a cross-reference audit on a sample of items where both sources report license data; measure agreement rate and characterize disagreement patterns (stale version, misparse, genuine conflict).

5. **Interaction with prior-art vault entries.** The line question intersects with `[[sources/obs-2026-08-19-hngh-knowledge-base-ingestion-in-llm-wiki]]` (knowledge-base ingestion) and `[[sources/SRC-2026-08-24-014]]` (legal/license context). I could not read these entries in full during this transition. **Hook:** Confirm that the R3 two-class split definition referenced in the line question matches the license-class semantics assumed in those vault entries, and that the audit gate is positioned correctly relative to the ingestion pipeline described there.

6. **Automatable check coverage.** R3 assumes that URL resolution and SPDX recognition can be automated cheaply. In practice, some license URLs redirect, require authentication, or serve non-standard content types. **Hook:** Measure the fraction of T0/T1 audit checks that are fully automatable vs. requiring manual adjudication. If the manual fraction exceeds ~40%, the per-batch audit cost may dominate and the gate threshold should be relaxed (or the sample size reduced) to keep the process sustainable.

## References
- Line question and prior beat material (2026-09-12, 2026-10-24) as provided in this transition.
- `[[sources/SRC-2026-08-24-003]]` — AgentSpec: Customizable Runtime Enforcement for Safe LLM Agents (llm-wiki vault; not read in full during this transition).
- `[[sources/obs-2026-08-19-hngh-knowledge-base-ingestion-in-llm-wiki]]` — Observation: Hngh Knowledge Base Ingestion in llm-wiki (llm-wiki vault; not read in full during this transition).
- `[[sources/SRC-2026-08-24-014]]` — opensource.guide: Legal (Licenses, DCO vs CLA) (llm-wiki vault; not read in full during this transition).
- General properties of OpenAlex and Crossref OA metadata as described in F1–F3. These are structural claims about the meaning of the fields, not version-specific empirical claims. I flag them as such: they reflect the documented semantics of `is_oa`, `oa_status`, and Crossref `license` arrays as understood from public documentation, but I did not verify against a specific API version or dataset snapshot in this transition.
- **No kernel file paths are cited.** I could not inspect `/home/bricker/Projects/etc/hngh` or hngh-automation during this transition. All implementation references are hooks (Open Threads 1, 2, 3, 4, 6), not citations.
