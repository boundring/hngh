# design docs/design/meta-cyclical-learning.md missing for plan 2026-10-05-meta-cyclical-learning-loop — delve: produce or locate the design

Status: crystallized 2026-10-05 from research line `fail-20261005-2026-10-05-meta-cyclical-learning-loop`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20261005-2026-10-05-meta-cyclical-learning-loop.md.

# Research line: meta-cyclical-learning-loop — final crystallization (contracting → contracted)

_line: design docs/design/meta-cyclical-learning.md missing for plan 2026-10-05-meta-cyclical-learning-loop — delve: produce or locate the design | state: contracting → contracted | basis: prior beat on this line + prompt-asserted facts only_

## Verification posture

This transition has no live read access to either repository. Facts taken as given because the prompt asserts them: `research-lines.tsv` exists; `docs/design/meta-cyclical-learning.md` does **not** exist (the plan is gated at `planned → designed`); the hngh kernel repository lives at `[redacted path] All other claims — especially anything about hngh internals or the contents of llm-wiki vault sources — are inferred from titles alone and are flagged as unverified below. Where the prior beat was truncated, that truncation is treated as a fact about the record, not smoothed over.

## Findings

**F1 — The gate is a single missing artifact, and the design draft already exists in line state.**
The prior beat produced a complete draft design (Sections 1–6, per its own record). The blocker on `2026-10-05-meta-cyclical-learning-loop` is not intellectual work but a commit step: the draft lives in research-line state instead of at `docs/design/meta-cyclical-learning.md`.

**F2 — The design is self-referential in a load-bearing way.**
The meta-cyclical learning loop's "act" step is what produced this design doc. Landing the doc is itself an execution of the loop it describes. This is not merely poetic — it means the doc's existence is evidence the loop's machinery works, and delaying it to "improve" the design is strictly dominated by landing it and letting the loop's own revert mechanism (R6) handle later-discovered flaws.

**F3 — The dominant threat model is self-referential prompt injection.**
The loop ingests external content (vault notes, issues, web material) and mutates its own policy. The CaMeL-derived boundary — untrusted content must never reach the policy-mutation code path; only validated, schema-typed records may — is the single most important design decision. Grounding: `SRC-2026-08-24-002` ("CaMeL: Defeating Prompt Injections by Design"), **title only; contents unverified**. The mechanism is sound as a design principle regardless of the source's details, but the attribution itself cannot be confirmed from this repository.

**F4 — Two failure modes are already-observed, not hypothetical.**
(a) The transport fault on a missing store directory (`obs-2026-08-26-hngh-create-run-transport-fault-on-missing-store-dir`, title only): a cycle that fails silently corrupts the outer loop's metrics because dead time becomes indistinguishable from idle scheduling. (b) The timezone rendering hazard (`sources/timezone-local-vs-utc-rendering-fabricates-missing-commits`, title only): local-time conversion at write time fabricates apparent gaps in commit/ledger history. Both argue for conventions enforced at the write path, not retrofitted.

**F5 — The prior beat's R7 is lost to truncation.**
The prior material was cut at 4000 bytes mid-sentence ("Anchor eac…"). The full text of recommendation R7 is not recoverable from the line state available here. It plausibly concerned anchoring each policy update to attestation records (given the attestation-related sources cited), but that is inference, not record.

## Recommendations (carried forward, condensed)

- **R1** — Land the existing draft at `docs/design/meta-cyclical-learning.md` verbatim or with light edits. Do not re-delve; further refinement in flight prolongs the gate with no information gain.
- **R2** — Make the policy-mutation channel schema-only: the update step accepts one validated record type (finding IDs, metric deltas, rationale hash); motivating content is referenced by ID, never passed through.
- **R3** — Pre-flight the store directory at the top of every cycle; on failure, write an attestation-of-failure if possible and abort loudly.
- **R4** — UTC at write time for all ledger, attestation, and beat-header timestamps; timezone conversion lives exclusively in render code.
- **R5** — Persist exactly four outer-loop metrics in the ledger itself: findings-per-transition, angle-reuse rate, dead-end rate, attestation coverage. Score and scoring data share one audit trail.
- **R6** — Revert policy updates strictly by ledger verdict over a defined window; version policy state alongside `research-lines.tsv` so objective drift is an auditable event, never silent.
- **R7** — *Unrecoverable from line state; see Open threads.*

## Open threads

1. **Recover or re-derive R7.** If the prior beat's full output is archived anywhere outside this line state, restore it; otherwise re-derive from the attestation-design pointer (`obs-2026-08-24-omp-context-via-billion-context-proxy-hngh-attestation-desig`, title only) once vault read access is available.
2. **Verify the vault sources.** All six cited sources are known by title only. Before the design doc ships as more than a working draft, confirm that `SRC-2026-08-24-002` and `SRC-2026-08-24-021` actually say what this line attributes to them; if not, the CaMeL boundary and evidence-ledger claims need re-grounding or de-attribution.
3. **Execute R1 on a host with write access.** Neither this transition nor the prior one could write to the repository. The next transition with filesystem access should perform the commit and flip the plan state.
4. **Unverified vault pointers not yet used.** `SRC-2026-08-18-009` ("Learning to Skip Blocks: Ultrametric Routing…") was cited as prior art but plays no role in the crystallized recommendations; either integrate it deliberately or drop it from the line's reference set.
5. **Plan-file path unknown.** The plan `2026-10-05-meta-cyclical-learning-loop` is referenced by ID; its on-disk location was never confirmed in line state. Locate it during the R1 commit so the design doc and plan cross-reference each other.

## Line disposition

[redacted: injection signature]

## References

- `research-lines.tsv` — line state (existence asserted by prompt).
- `docs/design/meta-cyclical-learning.md` — the missing design artifact; target of R1 (non-existence asserted by prompt).
- Plan `2026-10-05-meta-cyclical-learning-loop` — referenced by ID; on-disk path not confirmed.
- `[redacted path] — hngh kernel repository (path asserted by prompt; no internals verified).
- llm-wiki vault pointers, titles only, contents unverified:
  - `[[sources/SRC-2026-08-24-002]]` CaMeL: Defeating Prompt Injections by Design
  - `[[sources/SRC-2026-08-24-021]]` Autonomous Development Control (Evidence Ledger Design)
  - `[[sources/SRC-2026-08-18-009]]` Learning to Skip Blocks: Ultrametric Routing for Hardware-Acceleration
  - `[[sources/obs-2026-08-24-omp-context-via-billion-context-proxy-hngh-attestation-desig]]` Observation (attestation design)
  - `[[sources/obs-2026-08-26-hngh-create-run-transport-fault-on-missing-store-dir]]` Observation: hngh transport fault on missing store dir
  - `[[sources/timezone-local-vs-utc-rendering-fabricates-missing-commits]]` Local-time git date rendering observation

No external sources beyond this repository and the vault pointers above were consulted; none of the vault contents could be verified from this transition.
