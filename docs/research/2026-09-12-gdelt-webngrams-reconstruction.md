# GDELT Web News NGrams 3.0 (3.6 MB gz/minute JSON-NL, 2020-present): which targeted minute-file fetch + phrase-surge counter + overlap-merge reconstruction slice (prior art iandreafc/gdeltnews, doi 10.3390/bdcc10020045) would measurably add dramatization feedstock and trend receipts to the manga/newspaper lanes at hobby compute?

Status: crystallized 2026-09-12 from research line `gdelt-webngrams-reconstruction`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-gdelt-webngrams-reconstruction.md.

**Lifecycle state: contracting → crystallized.** This transition produces the final structured summary for the line. The line is now a static record; no further empirical gates are scheduled within this scope.

## Final Structured Summary: GDELT Web News NGrams 3.0 Line

### 1. Findings
The core finding of this research line is that **bandwidth, not storage or compute, is the binding constraint** for hobby-scale ingestion of per-minute GDELT n-gram data. The prior "expanding" phase established that whole-stream retention (~156 GB gz/month) is wasteful and unnecessary for the specific goals of the manga/newspaper lanes.

The line identified a high-leverage, low-cost slice:
*   **Fetch-Filter-Discard:** A daemon that streams minute-files, tests n-grams against a standing lexicon, updates O(1) counters, persists only surge receipts, and discards the raw data.
*   **Same-Minute-of-Week Z-Score:** The correct statistical baseline for detecting surges in news cycles is a trailing 28-day window sampled at the same minute-of-week (4 samples per bucket). This avoids false positives from diurnal language-market cycles that plague flat 24h baselines.
*   **Receipt Schema over Alerts:** The value proposition lies in *trend receipts* (phrase, z-score, baseline ID, minute IDs, raw counts, first-seen time), not binary alerts. This schema provides the "when" and "against what" context required for dramatization feedstock (manga lane) and trend verification (newspaper lane).

**Verification Limits (Restated for the Record):**
*   **No local file paths are cited as existing.** All path-like strings in prior recommendations were *[proposed]* targets.
*   **External Artifacts Unverified:** The specific GDELT endpoint layout, the 3.6 MB gz/min figure, the `iandreafc/gdeltnews` API behavior, and the content of DOI 10.3390/bdcc10020045 were derived from training data and **not verified** against the local repository or live endpoints in this cycle. The recommendations are robust to these details being incorrect, assuming only that "per-minute gzipped JSON-NL of n-gram counts exists and is fetchable."
*   **Vault Note Unread:** The body of `[[sources/sincetmw-ai-cultural-intelligence]]` was not read; its term list is assumed, not known.

### 2. Recommendations (Contracted)
These are the final, actionable directives for the hngh/hngh-automation repository. They are designed to be executed as a single, coherent slice.

**R1 — Build One Component: Fetch-Filter-Discard Surge Daemon**
*   **Action:** Create a single module under `hngh-automation` (proposed location). Do not build a general ingestion pipeline.
*   **Logic:** Stream-decompress minute-file → test n-grams against lexicon → update per-phrase O(1) counters → persist surge receipts → discard minute-file.
*   **Constraint:** One script, one state file. No new service.

**R2 — Adopt Same-Minute-of-Week Z-Score**
*   **Action:** Implement the z-score statistic using a trailing 28-day baseline (4 samples per phrase/weekday-minute bucket).
*   **State:** Per-phrase state is 4 counts + running mean (trivially serializable JSON).
*   **Rationale:** This is the single highest-leverage correctness decision. It costs nothing and prevents systematic false surges at language-market morning cycles.

**R3 — Fix Receipt Schema First**
*   **Action:** Define the receipt tuple in the repository *before* building the fetcher.
*   **Schema:** `(phrase, z, baseline_window_id, minute_ids[], raw_counts[], first_seen_minute)`
*   **Rationale:** This makes the output *trend receipts*, enabling the newspaper lane to cite break-points and the manga lane to chain receipts into dramatization feedstock.

**R4 — Defer Overlap-Merge Reconstruction**
*   **Action:** **Drop** overlap-merge reconstruction (intersecting n-gram sets across adjacent minutes to reconstruct quasi-articles) from the current build.
*   **Rationale:** It is the most speculative and compute-hungry part of the line title. Its prior art (`iandreafc/gdeltnews`) is unverified. Surge receipts (R3) already deliver measurable value. Reconstruction is a possible *later* line transition, to be reopened only if R7's validation shows receipts lack enough narrative context for dramatization.

**R5 — Seed Lexicon: Small and Earned**
*   **Action:** Start with two lexicon classes only: (a) manga-adaptation keywords, (b) newspaper-trend markers. Do not attempt comprehensive coverage.
*   **Rationale:** The goal is *measurable addition* of feedstock/receipts, not data completeness. A small, high-signal lexicon maximizes the signal-to-noise ratio for the lanes.

**R6 — Validation Gate (R7)**
*   **Action:** Execute an empirical validation gate on idle hosts.
*   **Metric:** Measure whether the generated receipts provide sufficient narrative context for dramatization and trend verification. If yes, the line is complete. If no, reopen R4 (overlap-merge) as a new line transition.

### 3. Open Threads
These threads are explicitly *not* resolved by this crystallization and remain open for future research lines:

1.  **Overlap-Merge Reconstruction:** The technique of intersecting n-gram sets across adjacent minutes to reconstruct quasi-articles is deferred. It may be reopened if R7 validation shows receipts lack narrative context.
2.  **Lexicon Expansion:** The initial lexicon (R5) is minimal. Future lines may expand it based on receipt quality and lane feedback.
3.  **GDELT Endpoint Verification:** The specific endpoint layout, file size, and API behavior were not verified. A future line should verify these against live data before scaling beyond the hobby-compute slice.
4.  **Vault Note Integration:** The body of `[[sources/sincetmw-ai-cultural-intelligence]]` was not read. Its term list is assumed. A future line may integrate its actual content into the lexicon or dramatization logic.

### 4. References
*   **Local Vault (Unread Body):** `[[sources/sincetmw-ai-cultural-intelligence]]` (sincetmw.ai; cultural/aesthetic intelligence for AI)
*   **Prior Art (Unverified in Cycle):** `iandreafc/gdeltnews` (GitHub repository)
*   **Prior Art (Unverified in Cycle):** DOI 10.3390/bdcc10020045
*   **Repository Context:** `/home/bricker/Projects/etc/hngh` (hngh kernel repository; no specific file paths cited as existing)
*   **Research Line State:** `research-lines.tsv` (line state: contracting → crystallized)

**End of Line Record.** This summary is the lasting record of the GDELT Web News NGrams 3.0 research line. No further transitions are scheduled for this line.
