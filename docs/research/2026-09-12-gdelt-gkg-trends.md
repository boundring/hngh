# GDELT GKG deeper features: which theme-timeline deltas, V2Counts enrichments, and multi-window NumSources aggregation would measurably improve the morning paper's story selection (docs/records/2026-09-12-gdelt-source.md deferrals)?

Status: crystallized 2026-09-12 from research line `gdelt-gkg-trends`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-gdelt-gkg-trends.md.

# research beat 2026-09-12 (final contraction)

_line: GDELT GKG deeper features: which theme-timeline deltas, V2Counts enrichments, and multi-window NumSources aggregation would measurably improve the morning paper's story selection (docs/records/2026-09-12-gdelt-source.md deferrals)? | state: contracting -> crystallized | model: (this beat)_

# Crystallized Record: GDELT GKG Deeper Features for Story Selection

This is the line's lasting record. It consolidates the prior expanding and contracting beats into a final summary: what we concluded, what we recommend, and what remains open. The line does not stop — open threads below are live continuation points for future beats.

---

## 1. Origin and scope

The line was seeded by deferrals recorded in `docs/records/2026-09-12-gdelt-source.md` (this repository): when the GDELT GKG source was first integrated into the morning-paper pipeline, three enrichment directions were explicitly deferred — theme-timeline deltas, V2Counts enrichments, and NumSources aggregation beyond a single window. This line asked which of those would *measurably* improve story selection.

Scope discipline note: one finding from the expanding beat (multi-window NumSources) was truncated mid-composition. The framing used in the contraction — 1 h / 6 h / 24 h windows plus short/long ratios — was a reconstruction from the line title and deferral themes, not verbatim prior text. It stands as a hypothesis of equal status to the other two signals, and this caveat is part of the record.

## 2. Findings

**F1. Three candidate signals, cleanly separable by editorial question.**

| Signal | What it adds over status quo | Editorial question |
|---|---|---|
| Theme-timeline deltas (6 h vs 7 d share-of-coverage delta) | Novelty/velocity independent of raw volume | "What is accelerating *right now*?" |
| V2Counts focus ratio (dominant-theme count / total theme count per document) | Ordinal theme intensity vs. binary presence | "Which candidate is actually *about* this theme?" |
| Multi-window NumSources (1 h / 6 h / 24 h + ratios) | Separates sustained stories from single-window spikes | "Is this story broadening or plateaued?" |

**F2. Cost/benefit ordering is inverted from value ordering.** V2Counts is cheapest (no new API surface — it rides on document-level GKG output already fetched) and attacks a concrete failure mode (clusters whose centroid document mentions the theme only in passing). Theme-velocity deltas are likely the highest editorial value but cost the most (baseline construction, per-theme windowing, cold-start handling).

**F3. Ratio features are the noise-robust formulation.** For both theme deltas and NumSources, ratios against a longer baseline damp single-window GDELT API noise — relevant because single-window raw counts conflate "12 flat sources" with "5 rising sources," which is precisely the ranking failure the deferral implies.

**F4. All three signals are evaluable offline.** Roughly 30 days of already-ingested GKG data plus existing selection logs suffice for a replay harness; nothing needs live tuning. (The 30-day figure comes from prior material on this line and was not re-verified against actual ingest history in this beat.)

**F5. Process lesson carries over.** Per `[[sources/hngh-storeless-cli-state-loss]]`, the hngh CLI does not hold state across invocations; any evaluation harness must persist intermediate features (parsed counts, computed deltas) to files between steps, not in process memory.

## 3. Recommendations (final, ordered)

**R1 — Build the replay-first evaluation harness before any pipeline change.** Shared dependency for R2–R4. Metric: precision@k of story selection with recall floored at current pipeline level. Persist all intermediate artifacts to files (F5). This avoids tuning against live morning runs.

**R2 — V2Counts parsing at ingest (do first after R1).** Parse `theme;count` pairs from the document-level GKG output the pipeline already fetches; store them per document record; derive dominant theme and focus ratio. Two immediate uses: (a) tie-break among same-theme candidates toward higher focus ratio; (b) weight story-cluster theme votes by V2Counts rather than unweighted per-document presence. Success criterion: measurable reduction in "story about X" clusters whose centroid only mentions X in passing.

**R3 — Multi-window NumSources aggregation.** Compute NumSources over 1 h / 6 h / 24 h windows; use short/long ratio as acceleration feature; keep 24 h absolute count as maturity floor. Precondition: verify per-document timestamps are retained by current ingest (assumption flagged in prior beat, still unverified).

**R4 — Theme-velocity gate (highest value, highest cost; do last).** Per-theme share-of-coverage over a 6 h window against a 7 d rolling baseline; gate or boost candidates whose theme delta exceeds a threshold tuned on the replay harness. Handles the "accelerating right now" question no other signal answers, but requires baseline cold-start policy and per-theme volume floors to avoid small-denominator blowups.

## 4. Open threads

- **OT1.** Whether document-level timestamps and raw V2Counts fields are actually retained by the current hngh GKG ingest — gates R3 and cheapens R2. Check against the ingest code in the hngh kernel repo (`/home/bricker/Projects/etc/hngh`) and the source record `docs/records/2026-09-12-gdelt-source.md`.
- **OT2.** The true precision@k baseline of current selection — needed before any signal can claim measurable improvement. No number exists yet on this line.
- **OT3.** Whether theme deltas should use absolute share-of-coverage or source-normalized share (GDELT theme tallies may be sensitive to overall ingest volume fluctuations) — decide during R4 design, informed by replay data.
- **OT4.** Interaction with the existing scout/wave machinery referenced in `[[sources/wave-delay-spec-fixes-20260827]]`: if selection signals change, scout schemas may need to carry the new features. Unexplored.
- **OT5.** Whether the three signals are redundant in practice (e.g., NumSources acceleration may proxy theme velocity on major stories) — answerable cheaply from the R1 harness via feature correlation before committing to R4.

## 5. Caveats on grounding

- The three prior-art pointers (`[[sources/SRC-2026-08-24-030]]`, `[[sources/hngh-storeless-cli-state-loss]]`, `[[sources/wave-delay-spec-fixes-20260827]]`) are llm-wiki vault references inherited from prior material; their contents were not re-read in this beat.
- `docs/records/2026-09-12-gdelt-source.md` and the hngh kernel repository are cited as the line's grounding sources; specific internal paths within the hngh kernel repo are *not* asserted here because they were not verified in this beat — OT1 covers the needed verification.
- GDELT GKG field semantics (V2Counts format, NumSources definition, theme timeline API behavior) are asserted only at the level carried by prior material. Any implementer should confirm against GDELT's own documentation before coding; those external sources were not verifiable from this repository.
- The 30-day replay corpus size is prior-material heritage, not a fresh measurement.

## References

- `docs/records/2026-09-12-gdelt-source.md` — this repository; the deferral record that seeded the line.
- `/home/bricker/Projects/etc/hngh` — the hngh kernel repository; ingest code and selection pipeline to be verified under OT1.
- `[[sources/SRC-2026-08-24-030]]` — llm-wiki vault; overnight multi-agent sprint case study (process context).
- `[[sources/hngh-storeless-cli-state-loss]]` — llm-wiki vault; basis for F5 / R1 persistence requirement.
- `[[sources/wave-delay-spec-fixes-20260827]]` — llm-wiki vault; scout schema context underlying OT4.
