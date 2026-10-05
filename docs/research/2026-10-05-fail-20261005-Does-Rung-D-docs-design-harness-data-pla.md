# Does Rung D / docs/design/harness-data-plane.md already fix a probe-record ingestion schema, and if not should the checker emit SARIF-shaped records?

Status: crystallized 2026-10-05 from research line `fail-20261005-Does-Rung-D-docs-design-harness-data-pla`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20261005-Does-Rung-D-docs-design-harness-data-pla.md.

# Research Line — Crystallized Record

**Line:** Does Rung D / `docs/design/harness-data-plane.md` already fix a probe-record ingestion schema, and if not should the checker emit SARIF-shaped records?
**Final state:** contracting → **closed (with one blocking open thread)**
**Wall time on this transition:** n/a — this is the crystallization, not a new expansion.

---

## Verification status (standing caveat for this entire record)

No beat on this line, including this one, ever achieved live read access to either repository. I cannot confirm that `docs/design/harness-data-plane.md` exists in the hngh kernel repo, and I cannot enumerate either repo's tree. Every claim below is tagged **verified** (supplied directly with the line/prior material), **inferred** (reasoned from prior material or general knowledge), or **unverified** (empirically checkable, not checked). SARIF 2.1.0 is referenced from general knowledge and was not re-verified against the OASIS spec. This separation is deliberate: the line's design conclusion is stable, but one empirical question remains open and is flagged as the sole blocking thread.

---

## Findings

**F1 — The design half of the question has a stable answer.**
The checker should **not** emit SARIF as its ingestion format. It should emit a canonical minimal JSONL probe record, with SARIF available as an optional, deterministic export projection at the reporting boundary. This conclusion holds under *both* possible outcomes of the schema audit, which is why the line can contract before the audit runs. *(Inferred; synthesized from F2–F5 across the line's beats.)*

**F2 — SARIF's taxonomy fits lint-like verdicts but not probe telemetry.**
SARIF `result.kind` (`pass` / `fail` / `review` / `informational`) maps cleanly onto checker verdicts, but durations, retries, counters, and environment fingerprints have no native home and would be exiled to property bags — incurring SARIF's schema cost while forfeiting its interoperability benefit. *(Inferred from general knowledge of SARIF 2.1.0; not re-verified against the spec.)*

**F3 — Coupling ingestion to SARIF couples the data plane to a worldview it will outgrow.**
An export adapter is cheap to write and free to deprecate; an ingested schema is neither. Ingestion formats should be minimal and owned by the data plane; presentation formats should be projections. *(Inferred.)*

**F4 — Provenance is shape-independent and non-negotiable.**
Given the CaMeL pointer (`[[sources/SRC-2026-08-24-002]]`) and the evidence-ledger design (`[[sources/SRC-2026-08-24-021]]`), probe records cross a trust boundary into the ledger. They must carry emitter identity and a content hash or signature regardless of record shape. SARIF has no native signing, so an integrity envelope is required either way — which removes the last argument for letting SARIF dictate the ingestion schema. *(Inferred; vault contents not re-read during this line.)*

**F5 — The empirical half of the question was never resolved.**
Whether `docs/design/harness-data-plane.md` already fixes a probe-record ingestion schema remains unknown. This is the line's only blocking open thread. *(Unverified.)*

---

## Recommendations

**R1 — Run the schema audit first; it is the only blocking step.**
Read `docs/design/harness-data-plane.md` (expected in the hngh kernel repo at `[redacted path] end-to-end, and grep both repos for existing record/schema artifacts: JSON Schema files, and the terms `probe`, `ingest`, `record`, `schema`. This resolves F5 and selects between R2 and R3. Everything else in this record is stable under either outcome. *(Unverified premise; audit is empirical.)*

**R2 — If the data-plane doc already fixes a schema: conform, don't fork.**
Emit exactly that schema from the checker. Build the SARIF projection as a separate downstream tool. Record any gaps (telemetry fields, provenance envelope) as issues against the doc rather than silently extending emitted records.

**R3 — If no schema is fixed: define the canonical record minimally, in the data-plane doc itself.**
Proposed shape *(inferred — proposed design, not repo fact)*:

```
{ probe_id, ts (RFC 3339), subject: {artifact_id, content_hash},
  verdict: pass | fail | review | informational, metrics: {...},
  emitter: {id, version}, evidence_ref, sig }
```

Field-level rationale: the verdict enum deliberately mirrors SARIF `result.kind` so the export projection is lossless for lint-like checks; `metrics` is the escape hatch SARIF lacks; `emitter` + `sig` satisfy the provenance prerequisite (F4).

**R4 — Treat the SARIF adapter as a one-way projection, owned downstream of ingestion.**
It consumes canonical records plus a static tool-descriptor manifest, is version-pinned against a specific SARIF release, and lives at the reporting/CI-integration boundary — never inside the checker and never inside the ledger write path. This keeps the data plane free to evolve while SARIF consumers see a stable artifact. *(Inferred; reconstructed from the truncated prior beat.)*

---

## Open threads

1. **Schema audit (BLOCKING).** F5 above. Small, well-scoped, and the only thing standing between this line and full closure. Any host with read access to `[redacted path] can run it.
2. **Provenance envelope specifics.** The exact signing/hashing scheme should be chosen against the evidence-ledger design (`[[sources/SRC-2026-08-24-021]]`) and the threat model implied by CaMeL (`[[sources/SRC-2026-08-24-002]]`), neither of which was re-read during this line. May warrant its own research line if the ledger doc is ambiguous.
3. **Schema versioning policy for `metrics`.** The escape-hatch object needs an evolution rule (additive-only? namespaced?) before emitters proliferate. Not blocking for R2/R3 but should land in the data-plane doc alongside the record definition.
4. **SARIF version pinning for the export adapter** (R4). Deferred until the adapter exists; the OASIS spec should be verified at that time rather than from memory.

---

## References

Repository paths (existence per line description / prior material; not independently verified):

- `docs/design/harness-data-plane.md` — expected in the hngh kernel repository at `[redacted path] *(cited by the line description itself)*
- `[redacted path] — hngh kernel repository root *(given)*
- `research-lines.tsv` — line state register *(given)*

llm-wiki vault pointers (read-only; contents not re-read during this line):

- `[[sources/SRC-2026-08-24-002]]` — CaMeL: Defeating Prompt Injections by Design
- `[[sources/SRC-2026-08-24-021]]` — Autonomous Development Control (Evidence Ledger Design)
- `[[concepts/agent-harness-governance]]` — Agent-Harness Governance Positioning
- `[[sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-]]` — Research Lesson (prior line failure record)
- `[[sources/obs-2026-08-19-hngh-knowledge-base-ingestion-in-llm-wiki]]` — Observation: Hngh Knowledge Base Ingestion
- `[[sources/SRC-2026-08-24-025]]` — Hngh Prior-Art Landscape Record (2026-08-24)

External (from general knowledge; **not verified** during this line):

- SARIF 2.1.0, OASIS Standard — referenced for `result.kind` taxonomy, property bags, and absence of native signing. Verify against the spec before implementing R4.

**Bottom line:** the design question is answered — canonical minimal JSONL for ingestion, SARIF as optional downstream projection, provenance envelope mandatory regardless. The empirical question (does the data-plane doc already fix a schema?) is the single blocking thread; run the R1 audit to close the line fully.
