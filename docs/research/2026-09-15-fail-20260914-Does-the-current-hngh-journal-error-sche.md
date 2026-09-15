# Does the current `hngh` journal-error schema include a mandatory `waiver_metadata` object, and if so, what are the required fields for expiry and recheck conditions?

Status: crystallized 2026-09-15 from research line `fail-20260914-Does-the-current-hngh-journal-error-sche`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260914-Does-the-current-hngh-journal-error-sche.md.

# Crystallization — Research Line

**Line:** Does the current `hngh` journal-error schema include a mandatory `waiver_metadata` object, and if so, what are the required fields for expiry and recheck conditions?
**Lifecycle:** contracting → crystallized
**Status:** Unresolved — closed with an honest record of what is and is not established.

---

## Findings

**What is established from the line's own record:**

1. **The question was posed and oriented, but no schema evidence was ever captured.** The prior beat (2026-09-15) records only orientation and intent to search for `waiver_metadata` and the journal-error schema in `~/Projects/etc/hngh`. It contains no search results, no schema excerpts, and no file citations from the kernel repository. The beat's `wall_s: 6.0` is consistent with a transition that ended before any verification ran.

2. **Contextual signals exist but do not answer the question.** The prior-art pointers reference an "attestation freshness recheck (moment-of-action)" concept and a roadmap note, which are thematically adjacent to expiry/recheck conditions. However, thematic adjacency is not evidence that `waiver_metadata` exists in the journal-error schema, is mandatory, or has particular required fields.

3. **I cannot verify the repository contents in this transition.** I have not been able to read or search `~/Projects/etc/hngh` or the host repository here. Therefore I make **no claim** that `waiver_metadata` exists, that it is mandatory, or that it contains expiry/recheck fields. Any answer asserting either "yes" or "no" would be fabrication, not research.

**Bottom line finding:** The existence, optionality, and field requirements of `waiver_metadata` in the `hngh` journal-error schema are **unknown as of crystallization**. The line's honest lasting record is a negative one: this question was not resolved during its active period.

## Recommendations

1. **Do not treat "no finding" as "no such field."** Downstream consumers of this line must not assume the schema lacks a waiver mechanism. The correct handoff is "unverified," not "absent."

2. **Concrete next search plan** (for whoever reopens the line or works adjacent to it):
   - `grep -rn "waiver_metadata" ~/Projects/etc/hngh` — existence check across the kernel tree.
   - Locate the journal-error schema definition (likely candidates to *search for*, not asserted to exist: schema files mentioning `journal`, `error`, or JSON Schema / dataclass / TypedDict definitions of journal entries).
   - If `waiver_metadata` is found, inspect its type definition for fields matching expiry (`expires`, `expiry`, `ttl`, `valid_until`) and recheck (`recheck`, `recheck_after`, `moment_of_action`, `freshness`).
   - Cross-check against the roadmap note in the vault to see whether the waiver mechanism is planned vs. implemented — a feature on the roadmap is not a feature in the schema.

3. **Record intermediate evidence in future beats.** The prior beat ended at orientation. A beat that captures even partial grep output would have let this line contract with substance. Recommend beats persist raw search output (paths + matched lines) before interpretation.

## Open Threads

- **Primary (unresolved):** Does `waiver_metadata` exist in the journal-error schema? Is it mandatory? What are its expiry and recheck fields?
- **Secondary:** How does the "moment-of-action freshness recheck" concept (vault note) map onto schema-level fields, if at all? Is it enforced at write time, read time, or both?
- **Tertiary:** Is the waiver mechanism documented in the roadmap as shipped or as pending work? A schema/roadmap discrepancy would itself be a finding worth a new line.

## References

*Cited because they appear in this line's prior material as existing vault notes (read-only pointers in the llm-wiki vault):*

- `concepts/hngh-lessons-current` — "Hngh Lessons — Current"
- `sources/SRC-2026-08-24-026` — "Hngh Roadmap (current state, 2026-08-24)"
- `concepts/moment-of-action-freshness` — "Attestation freshness recheck (moment-of-action)"
- `sources/obs-2026-08-25-guardrail-bug-filed-upstream-hngh-analytics-live-readme-curr`
- `sources/grep-tab-escape-matches-nothing` — "GNU grep treats \t as a stray escape; use awk -F'\t'" (tooling note relevant to searching TSV-adjacent files)

*Not cited as existing:* no file paths inside `~/Projects/etc/hngh` are referenced here, because I could not verify any of them during this line's active period. The kernel repository path itself is the stated search target, not a confirmed source of any claim above.
