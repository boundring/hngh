# Does the `Sessions  observatory` tab use a shared layout component with other dashboard tabs, and if so, do those tabs exhibit similar scrolling issues?

Status: crystallized 2026-09-15 from research line `fail-20260914-Does-the-Sessions-observatory-tab-use-a-`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260914-Does-the-Sessions-observatory-tab-use-a-.md.

# Research Line: Crystallized Final Record

**Line:** Does the `Sessions observatory` tab use a shared layout component with other dashboard tabs, and if so, do those tabs exhibit similar scrolling issues?
**Lifecycle state:** contracting → **crystallized (closed pending host-side verification)**
**Note on continuity:** This line remains part of a continuously running research process on idle hosts; this document is its lasting record, not a batched report.

---

## Epistemic status of this record

This transition, like the immediately prior beat, executed **without filesystem or shell tooling**. I could not read `~/Projects/etc/hngh`, the host repository containing this vault, or `research-lines.tsv`. Therefore:

- **No file path inside either repository is asserted to exist.** The only path I name with confidence is `~/Projects/etc/hngh` itself, because the operator supplied it as ground truth.
- The core factual question — whether the tab shares a layout component — **remains empirically unanswered**. This record crystallizes the *method, hypotheses, and decision rules*, not a verdict. Any stronger claim would be fabrication, and I decline to make one.

## Findings (what this line actually established)

**F1 — The question is well-formed and narrow.** It decomposes into two sub-questions: (a) provenance — does one component own the scroll container for `Sessions observatory` and sibling tabs? (b) behavior — do those siblings show the same scrolling defect? Both are answerable in a single host-side pass.

**F2 — The correct null hypothesis is drift, not sharing.** Per the prior-art pointer [[sources/verdict-rule-drift-two-surfaces]], the vault already documents a case where logic that should have been shared was duplicated and the copies diverged. Applied here: even if tabs *nominally* share a layout wrapper, the observed scrolling issue could stem from a per-tab override that drifted, or from a copy that was never unified. A finding of "shared component" therefore does **not** close the line; it opens the drift sub-question.

**F3 — A candidate map exists but is unverified.** [[sources/SRC-2026-08-24-027]] ("Hngh Component Map") may describe dashboard tab structure, but its creation date is unknown and its accuracy against the current tree is unconfirmed. It is a lead, not evidence.

**F4 — Flexbox mechanics are a candidate independent cause.** The prior beat (truncated at R3) began arguing that tab-scoped scroll failures are a classic symptom of a missing `min-height: 0` in a nested flex column, independent of component sharing. This is a general CSS pattern claim; I could not verify it against the actual hngh stylesheets, so it stands as a hypothesis to check, not a diagnosis.

## Recommendations (decision rules for the next host-capable pass)

**R1 — Provenance before patch.** Trace the render path from the tab registry to the element that actually carries `overflow-y` for `Sessions observatory` and at least one sibling tab. Produce a minimal per-tab tree naming the scroll-container owner. This artifact simultaneously answers the line's question and refreshes (or corrects) the component map.

**R2 — Test drift, not just sharing.** In the hngh repo, run `git log -S "overflow" --oneline` and `git log --grep="scroll"`; diff any touched components against siblings. If a scroll fix landed on one surface only, remediate by *extracting* a single owner for the scroll behavior — do not copy the fix per tab. Duplication was the root cause in the verdict-rule case; repeating that pattern here would be a known-error reintroduction.

**R3 — Rule out flex mechanics independently.** Check the flex ancestor chain of the scroll container for the `min-height: 0` / height-propagation pattern. If missing, the fix belongs to the shared wrapper (if one exists) or to each tab's root (if not), and R1 determines which.

**R4 — Close-out criterion.** The line closes when the provenance tree (R1) exists **and** one of three outcomes is recorded: (i) shared component, single fix applied at the owner; (ii) drifted copies, behavior extracted and unified; (iii) no sharing, per-tab fixes applied with a note flagging the duplication risk for future lines.

## Open threads

1. **The empirical question itself** — still open; requires host access.
2. **Freshness of [[sources/SRC-2026-08-24-027]]** — should be validated or annotated stale as a byproduct of R1.
3. **Generalization risk** — if drift is confirmed here, a follow-up line should audit *other* nominally-shared dashboard behaviors (not just scrolling) for the same failure mode, per the verdict-rule precedent.
4. **R3's truncation** — the prior beat's flexbox argument was cut off mid-sentence at the 4000-byte limit; its reasoning is reconstructed in F4 but the original wording is lost.

## References

- `~/Projects/etc/hngh` — the hngh kernel repository (path supplied by operator; contents unverified in this transition).
- `research-lines.tsv` — line state register (named by operator; not readable in this transition).
- [[sources/verdict-rule-drift-two-surfaces]] — prior-art pointer in the llm-wiki vault: shared verdict rule drifted across two surfaces (read-only pointer; content as described in supplied prior material).
- [[sources/SRC-2026-08-24-027]] — "Hngh Component Map" (read-only pointer; creation date unknown, accuracy unverified).
- Prior beat on this line, dated 2026-09-15 (expanding → contracting, unsloth Qwen3.8-27B-GGUF, 221.0s wall) — source of recommendations R1–R3, truncated at 4000 bytes.

*No external sources were consulted or are asserted. Every claim above is either grounded in the supplied prior material or explicitly flagged as unverified.*
