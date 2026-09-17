# hist-records-format: docs/records/ record body format verification

Verified 2026-09-15, repo /home/bricker/Projects/etc/hngh. READ-ONLY.
Builds on hist-records-recency.md (ordering, thin-harvest policy) and
hist-windows-schema.md (merged feed envelope).

## The governing rule (README future-records rule)

docs/records/README.md, final line before the spine link:

> Future records name their scope, evidence command, observed result,
> and remaining unknowns.

Plus the header doctrine: "Records preserve verified facts, decisions,
and bounded unknowns. They do not authorize a future action."

So the CONTRACT is: title / scope / evidence command / observed result /
remaining unknowns. It is a convention, not a schema: records are free
prose markdown, not structured frontmatter.

## How the rule maps to real records

Records follow the rule in spirit with varied section vocabulary:

- Title: H1 line, `# YYYY-MM-DD — <slug sentence> (optional node id)`.
  Plain `YYYY-MM-DD` (no em dash) also occurs (loop-history record).
- Scope: usually folded into the opening paragraph under the H1 (the
  "Task:" / "Source:" line) rather than a `## Scope` heading.
- Evidence/observed result: a `## Verification` (or "Evidence read",
  "Validation") section with actual commands and pass counts
  (e.g. "14/14 OK", "make test — ALL PASS").
- Unknowns: `## Known open question ...`, `## Verification blocker`,
  `## Known wiring gap`, `## Not rewritten` — explicit fail-open
  declaration of what was NOT resolved.

## Sample newest records (2026-09-15) — observed section structures

- viz-schema-version-gate: What landed / probe-verify-suite definition /
  Verification / Known open question (cross-node). Commands + counts in
  Verification; unknowns named with owner ("Flagged to the seam owner
  and the coordinator").
- viz-schema-validation-seam: Contract / API / Decisions / Known wiring
  gap (gated, not papered over) / Validation.
- swarm-coordination-lessons: Source line, then incident TABLE (markdown
  pipe table: #, Incident, Cause class, How resolved, Durability) —
  dense machine-readable-ish rows inside prose.
- rehearsal-lane-step-2-landing: closest to the canonical rule: Question
  / Evidence read / Doctrine applied / Findings / Verification blocker
  (evidence, not silence) / Recommended next line.
- loop-history-526cd3f-exemption-cure-completed: What was wrong / The
  cure / Verification / Not rewritten.

## Machine-consumable fields

- NO YAML frontmatter, NO per-record metadata fields, NO ids/tags in
  any sampled record. Machine consumption relies on:
  - filename `YYYY-MM-DD-<slug>.md` (date + slug = identity);
  - H1 line (human title, ISO date + em dash);
  - `## Verification` sections containing literal shell commands and
    pass/fail counts (greppable but not schema'd);
  - occasional markdown tables (swarm-coordination-lessons incident
    catalog) — the only tabular payloads seen;
  - PROBE-style machine-parsable one-liners are quoted inside records
    (e.g. `PROBE-VERIFY-SUITE as-of-utc=... head=... _clean=yes`) but
    as documentation of tool output, not record metadata.
- The records/README.md index is the reverse: one bullet per record
  (path + one-sentence "records X" summary), with the four 2026-09-09
  anchor records as markdown links at the end. Machine traversal =
  sorted filenames + README bullets; nothing else to parse.
- Contrast with hist-windows-schema.md: that feed wraps EXTRACTED
  content in a versioned envelope; records themselves carry no
  envelope. Any machine consumer must define its own extraction layer
  (as automation already does elsewhere: harvest/extract scripts read
  these files ad hoc).

## Conclusion

Format = convention over schema: date-slug filename, H1 title, prose
opening that states scope, an evidence/verification section with real
commands and counts, and an explicit unknowns/blocker section. The
README future-records rule is honored in substance; section headings
vary freely. No frontmatter or stable machine fields exist, so a
machine-consumable merged feed must extract heuristically or the
envelope must live outside the record file.
