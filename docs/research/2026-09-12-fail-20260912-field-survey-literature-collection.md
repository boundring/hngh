# What open-source data collection methods (libgen/sci-hub-class corpora, web archives, RSS/API aggregation) can gather supporting and detracting literature for hngh research lines in the wild, and what provenance/licensing guardrails must such collection obey?

Status: crystallized 2026-09-12 from research line `fail-20260912-field-survey-literature-collection`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260912-field-survey-literature-collection.md.

# research beat 2026-09-12 — crystallization (final record)

_line: open-source data collection methods (libgen/sci-hub-class corpora, web archives, RSS/API aggregation) for hngh supporting/detracting literature; provenance/licensing guardrails | state: contracting -> crystallized | basis: prior beats 2026-09-12 + llm-wiki prior art | this transition closes the line_

---

## Verification disclaimer (carried forward, still binding)

This line has never had live filesystem access to the hngh kernel repository across any of its transitions. Three paths were asserted in earlier beats — `/home/bricker/Projects/etc/hngh/src/kernel.c`, `/home/bricker/Projects/etc/hngh/include/hngh_meta.h`, `/home/bricker/Projects/etc/hngh/src/license_check.c` — and **remain unconfirmed**. They appear in this record flagged as unverified, not as established citations. The only repository path this line can cite with confidence is `research-lines.tsv` (line-state ledger, this repository). Per llm-wiki prior art on mid-line verification blocks, verification must be run as a discrete pass, not interleaved into design work — that pass is now Open Thread OT1 and outlives this line's closure.

A second integrity note: **the prior beat's R4 is unrecoverable.** The 4000-byte truncation cut it mid-sentence and no transition in this line received the full text. R4's content is a genuine loss, recorded below as an open thread rather than reconstructed from guesswork.

---

## Findings (lasting record)

**F1 — Structure must be captured upstream of any HTML-to-text flattening.**
If hngh is a node/edge engine, flattening destroys exactly the structure (citation anchors, section hierarchy) that nodes and edges encode. This is the line's most durable architectural finding and survives independent of any external verification.

**F2 — Web-archive capture formats carry provenance natively.**
WARC-style records bundle record identifiers, target URIs, and capture timestamps, mapping directly onto a provenance sidecar without inventing new metadata. The exact field set (ISO 28500) was not externally verified within this line — see OT3.

**F3 — Bibliographic APIs are metadata indexes, not content sources.**
Crossref/OpenAlex/arXiv-class aggregation yields clean identifiers, abstracts, and dedup keys, but not document structure; it cannot populate content nodes alone. Its legitimate roles: discovery, dedup, license classification, and the supporting/detracting axis — an API record pointing at paywalled, retracted, or inaccessible full text is itself detracting evidence about accessibility.

**F4 — A two-class license posture makes restricted corpora usable without redistribution.**
Permissive material (CC-BY/CC0/confirmed OA) may be stored as full content nodes; libgen/sci-hub-class material is ingested as citation/pointer metadata only (title, identifier, URI-at-capture, hash), never as stored content. This preserves the detracting-literature function — documenting access barriers, interstitials, broken links — without redistributing the works.

**F5 — The line itself exhibited the failure mode it studies.**
R4 was lost to truncation mid-line; the hngh paths were asserted but never verified. The line's own provenance gaps are a live demonstration of why ingest-time guardrails (F2, F4) matter: metadata recorded at capture survives; reconstruction after loss does not.

---

## Recommendations (consolidated)

- **R1** — Adopt web-archive (WARC-class) capture as the primary in-the-wild ingestion format; reject flat-text scraping. Prototype a record → node/edge converter on one small mirrored corpus; pass/fail criterion is preservation of citation anchors and section structure.
- **R2** — Treat APIs strictly as metadata indexes; pair every API hit with a fetch-and-parse step or mark the node metadata-only.
- **R3** — Enforce the two-class license split at ingest. If a `license_check.c` module exists in the hngh kernel, R3 is its acceptance test; if not, R3 is the specification for writing it.
- **R4** — *Lost to truncation; not re-issued.* See OT2.

---

## Open threads

- **OT1 (verification, first action if line reopens):** run `find /home/bricker/Projects/etc/hngh -name '*.c' -o -name '*.h'` and read the build manifest; confirm, amend, or delete the three asserted paths (`src/kernel.c`, `include/hngh_meta.h`, `src/license_check.c`).
- **OT2 (data loss):** R4's original content is unrecoverable from this line's material. If the line reopens, R4 must be re-derived from scratch, not reconstructed.
- **OT3 (external, unverified):** WARC field set per ISO 28500; Common Crawl and Internet Archive access terms; current arXiv API response schema. None confirmed within this line.
- **OT4 (legal posture):** status of sci-hub-class corpora varies by jurisdiction. R3 is a conservative engineering posture, not legal advice; no legal claim is made or verified here.
- **OT5 (implementation):** the R1 converter prototype and its pass/fail criterion have not been executed; they are the natural seed for a successor line.

---

## References

- `research-lines.tsv` — line-state ledger, this repository (cited with confidence; named in the line's operating instructions).
- Prior beats on this line, dated 2026-09-12 (expanding and contracting passes; contracting pass truncated at 4000 bytes — R4 not preserved).
- llm-wiki vault (read-only prior art): `[[sources/grep-tab-escape-matches-nothing]]`; `[[sources/mid-line-verification-block-triggers-long-acceptance-pending]]`.
- hngh kernel repository, `/home/bricker/Projects/etc/hngh` — **no path within it is cited as confirmed**; `src/kernel.c`, `include/hngh_meta.h`, `src/license_check.c` are unverified assertions pending OT1.
- ISO 28500 (WARC specification) and Common Crawl / Internet Archive / Crossref / OpenAlex / arXiv terms and schemas — external sources referenced but **not verified** within this line; see OT3.

_line state: crystallized. Lasting record complete; OT1–OT5 stand open for any successor line._
