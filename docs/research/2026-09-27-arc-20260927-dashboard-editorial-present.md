# How does composition surface real hngh editorial rows (alerts, fleet notes, real operator decisions) instead of only stub-class internal content?

Status: crystallized 2026-09-27 from research line `arc-20260927-dashboard-editorial-present`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-arc-20260927-dashboard-editorial-present.md.

# research beat 2026-09-27 — contraction

_line: How does composition surface real hngh editorial rows (alerts, fleet notes, real operator decisions) instead of only stub-class internal content? | state: contracting -> contracted_

This is the line's lasting record. It is written at the point where the line contracts, and it is deliberately conservative about evidence: the retained material on this line never confirmed a single file inside the kernel tree, and this beat had no shell access to change that. Everything below distinguishes what the line *established* from what it *proposed but never verified*.

---

## Verification boundary (read first)

- **Attested locations only.** The only paths I am confident exist, because they are named in the line hand-off itself, are the kernel repository `[redacted path] and the line-state file `research-lines.tsv`. Neither tree was inventoried during this line's expanding phase.
- **No verified kernel paths.** Every path appearing in the retained recommendations (e.g., a hypothesized `<hngh-root>/src/composition/` module and `row_classifier.rs` within it) was explicitly marked **[UNVERIFIED]** in the distillation beat. They remain hypotheses and are *not* cited as references below.
- **Prior-art pointers unopened.** The three vault links attached to this line were read-only pointers; their full contents were never read into the retained record.
- **Truncation loss.** The distillation beat was truncated at 4000 bytes. Finding F3 and any recommendations beyond R3 are not recoverable from the retained material.

## Findings

- **F1 — The single-host trap.** Confirming one surviving row-class on one host is not evidence of fleet-wide composition health. Grounded in prior-art lesson `LES-fail-20260915-If-R1-confirms-1-surviving-class-on-1-ho`. *Citation-hygiene note for successors: that lesson's "R1" predates this line (2026-09-15 vs 2026-09-27) and is not this line's R1.*
- **F2 — Decisions Register as strongest editorial-source candidate.** The vault pointer `SRC-2026-08-24-023` ("Hngh Decisions Register") was identified as the most likely source of genuinely editorial rows. **Status: hypothesis only.** Whether composition code ingests it was never checked.
- **F3 — Lost.** Content destroyed by the 4000-byte truncation of the distillation beat. Marked lost; do not reconstruct from memory.
- **F4 — Editorial-class criteria (the line's main durable artifact).** A row is editorial-class iff: (1) attributable to an operator or fleet event, not internal scaffolding; (2) carries a timestamp from the event domain, not emission time; (3) references an entity outside the composition layer (host, alert ID, decision ID). This definition is the line's answer to "what would 'real' even mean?" and survives contraction regardless of later implementation.

## Recommendations (final form)

- **R1 — Classifier before measurement.** Implement the F4 criteria as a concrete function before any composition health claim. Target module location inside `[redacted path] is *unknown*; a

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
