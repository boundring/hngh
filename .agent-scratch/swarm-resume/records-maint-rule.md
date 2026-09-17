# Task records-maint-rule: the docs/records index maintenance rule

READ-ONLY exploration, 2026-09-15. Question: what rule governs updating the
`docs/records/` index (docs/records/README.md)?

## Headline finding

There is NO single explicit "when you add a record, update the index" rule
stated anywhere in AGENTS.md, docs/README.md, contributing docs, or
automation tests. The maintenance obligation is distributed across several
normative statements, each quoted below with file:line.

## Exact rule text (file:line)

1. AGENTS.md:73-75 (commit protocol, the closest thing to the rule):
   "Commit a work slice as soon as it is verified: the full gate (`make test`)
   passes, the change is confined to the task's stated scope, docs/records are
   updated, the first-commit message matches the slice, and the working tree
   carries no unrelated changes."
   => "docs/records are updated" is a required condition of every verified commit.

2. AGENTS.md:81:
   "Record architecture-relevant work in `CHANGELOG.md` and `docs/records/`."

3. AGENTS.md:62-63:
   "Treat prior-state records (`docs/records/`) as the authoritative history
   of the refactor."

4. docs/records/README.md:1:
   "Records preserve verified facts, decisions, and bounded unknowns. They do
   not authorize a future action."
   (This is the "records format spec" other docs cite, e.g.
   automation/docs/records/2026-09-01-biographic-capture.md:89.)

5. docs/records/README.md:180:
   "Future records name their scope, evidence command, observed result, and
   remaining unknowns."
   (Content rule for each record; the index entries themselves are one
   bullet per record file, e.g. `- \`2026-08-24-...md\` records ...`.)

6. docs/records/README.md:175-178 (the deliberate-recency boundary):
   "The harvest from 2026-09-01 onward is thin here on purpose: recent
   work-slice facts live closer to their surfaces (plan files, reports.md,
   the changelog). The four 2026-09-09 rows above are the anchor records
   the documentation spine ties itself to."
   => New records are NOT all expected to be indexed; post-2026-09-01 facts
   intentionally live in plan files/reports.md/changelog instead. Only
   anchor records (the four 2026-09-09 entries, lines 171-174) are spliced in.

7. docs/README.md:162-165 (historical-tree rule):
   "<!-- HISTORICAL: records/, journal/, research/ - point-in-time evidence,
   decisions, and long-form history. Rule: trust CURRENT for how things
   work today; cite HISTORICAL for how they got that way, never as
   current behavior. -->"
   and docs/README.md:170: "`records/`, `journal/`, and `research/` are the
   HISTORICAL tree." with docs/README.md:172-173 linking
   "[Records](records/README.md)" from the documentation spine.

## Observed practice (evidence the rule is followed)

- automation/agent-handoffs.md:102: "2026-09-09 anchor records indexed in
  docs/records/README (two hops from the spine)" - indexing was part of a
  docs-spine promotion slice.
- docs/research/2026-09-11-public-face-redesign.md:347: "docs/records/README.md:
  current-vs-historical two-shelf banner."
- docs/project/plans/2026-09-09-presentation-pass-1.plan.md:47: verification
  "the generated book lists the new records" - the publication pipeline
  (scripts/generate-publication) consumes the spine, which reaches records
  via docs/README.md -> records/README.md.
- automation/tests/test-getting-started-links.py:106 references
  `records/README.md` (link-presence test, not an index-maintenance test).
- No automation test enforces index completeness (grep over automation/
  tests found none).

## Bottom line

The maintenance rule is: every verified commit must have docs/records
updated (AGENTS.md:74), architecture-relevant work recorded in CHANGELOG.md
and docs/records/ (AGENTS.md:81), each record following the content format
of records/README.md:180; but the index itself is intentionally thin after
2026-09-01 (records/README.md:175-178) - only anchor records get explicit
index bullets, everything else relies on the plan/reports/changelog
surfaces plus the link-check gate.
