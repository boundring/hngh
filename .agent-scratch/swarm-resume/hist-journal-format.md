# Journal output format spec (recent-history spine)

Task: `hist-journal-format` — spec of the `docs/journal/YYYY-MM-DD.md`
output produced by `scripts/generate-publication --daily`: `build_journal`
section order, ledger line formats, `mission_line` candidate resolution,
and the README dispatch table row format. Read-only exploration,
2026-09-15. Sibling artifacts: `hist-journal-location.md` (path seam:
`JOURNAL_DIR = ROOT / "docs" / "journal"`, env `HNGH_PUB_ROOT`),
`hist-windows-schema.md` (merged feed envelope).

Source of truth: `scripts/generate-publication` (kernel code surface;
machine sessions read-only there). Key functions: `build_journal`,
`dispatch_section`, `story_section`, `journal_narrative`, `mission_line`,
`dispatch_table`, `check_day`.

## 1. build_journal section order (exact)

`build_journal(day)` emits, in order (blank line between all blocks):

1. `# Journal — {day}` (H1 title)
2. **DISPATCH section** (`dispatch_section`): `## DISPATCH`, blank line,
   three bullet lines (sessions/spend/calls, research lines advancing,
   open operator items), `Verdict: advancing|holding|quiet.`, blank line,
   one `<!-- sources: ... -->` HTML comment citing each feed
   (budget.md, telemetry.db, operator-items.json, research-lines.tsv).
3. **Narrative paragraph** (`journal_narrative`): single plain-text
   paragraph, no header, assembled from arcs (commits/candidates,
   check-ins, timeline rows/rotations); quiet days get the fixed
   "Nothing committed, checked, or rotated..." paragraph.
4. `## The ledger (machine-checked)` — the only lines `--check` parses
   (see section 2).
5. `## The day's story` — `story_section`: zero or more blocks each
   `<!-- feeds: PATHS -->` + paragraph (hall session/telemetry, digest
   lead line, stall ledger, lessons), closed by a `Verdict: ...` line
   mentioning advancing lines, open items, blockers. Deterministic, no
   model call at render time.
6. `## The book of the day` — fixed boilerplate cadence paragraph.
7. `## The day's commits` (only if n > 0 commits): one bullet per
   commit, `- `{7-char sha}` {mission_line(subject, sha)}`.

## 2. Ledger line formats (machine-checked)

Inside `## The ledger (machine-checked)`, four dash bullets:

- `- **{n}** commits; **{candidates}** candidate-bound[; **{labeled}** labeled-excluded].`
  (the labeled clause only when labeled > 0)
- `- **{len(checkins)}** check-in[s] #{c1} #{c2}....` (plural "s" only
  when count != 1; `(none)` when zero)
- `- **{len(timeline)}** timeline rows: {kind}×{count} ...|none.`
  (kinds sorted alphabetically; only done/event/rotation rows count)
- `- Public edition: docs/dispatch/{day}.md (same feeds, markdown).`
  (fixed string, not checked)

`--check` (check_day) regex-verifies exactly three of these:
`- \*\*(\d+)\*\* commits` vs `len(day_commits)`,
`; \*\*(\d+)\*\* candidate-bound` vs candidate count (subjects starting
`hngh: candidate`), `- \*\*(\d+)\*\* check-in` vs check-in headings
(`^## {day} — check-in #(\d+)` in docs/project/checkin.md). If the
ledger bullet shapes are absent entirely, the journal is classified
operator-authored and `--check` refuses (distinct message, exit 1) —
it never edits operator text. Timeline row count is NOT verified by
--check. Journals are write-once: --daily refuses to rewrite an
existing journal unless --force.

## 3. mission_line candidate resolution

`mission_line(subject, sha)` produces the human text after the sha in
commit bullets. Cases:

- Non-candidate subject (anything not matching
  `^hngh: candidate (\S+)$`): returned verbatim.
- Candidate commit (`hngh: candidate <full-hash>`): scan
  `sorted(docs/records/*.md)` in order; first record whose full text
  contains the **full** hash wins. Output:
  `candidate {full[:7]} — {record H1 title}` (H1 = first `# ` line,
  title-stripped; fallback to record stem if no H1).
- Candidate with no citing record (no record mentions the full hash):
  `candidate {full[:7]} — recorded run (no mission line in records)` —
  honest placeholder, never an invented mission.

## 4. README dispatch table row format

`dispatch_table(day)` emits the block injected inside the README
sentinels `<!-- dispatch:begin -->` / `<!-- dispatch:end -->`
(`readme_dispatch`; sentinels missing or unterminated -> refuse, exit 1,
never inject):

- `| {day} | {sessions} | ${spend:.2f} | {advancing} | {open_items} |`
  (one table row, prepended at top of sentinel block)
- blank line
- `Deep read: [the journal](docs/journal/{day}.md).`

Column semantics (from `dispatch_numbers`, all fail-open -> 0/quiet):
sessions = budget.md lines dated `{day}` ending `session-run`; spend/
calls = telemetry.db `events` where kind=session-cost in last 24h;
advancing = research-lines.tsv states in planned+expanding; open_items
= operator-items.json status=open. Verdict: advancing if advancing>0,
else holding if any reviewed, else quiet. Same feed numbers back the
journal DISPATCH section, so the two surfaces cannot disagree.

## 5. Seams and constraints

- All reads are repo-relative via `ROOT` (`HNGH_PUB_ROOT` env seam,
  tests-only override; see hist-journal-location.md). Story section
  reuses automation/jobs parsers (`digest_ledger`, `digest_public`)
  loaded by path so formats cannot diverge.
- No secrets, no userspace `~/.hngh/` data in journal output; every
  derived block carries an HTML-comment feed citation.
- Tests: `tests/scripts/test-generate-publication.py` (fixture-backed,
  monkeypatches `mod.JOURNAL_DIR`); certification record
  `docs/records/2026-09-06-generate-publication-post-hoc-certification.md`.
