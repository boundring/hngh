# Spec: journal ledger-line format vs story section, and the --check contract

Ground truth: `scripts/generate-publication` — `day_stats`/`day_checkins`/
`day_timeline` (lines 105-136), `story_section` (292-367), `journal_narrative`
(369-394), `build_journal` (396-441), `check_day` (468-493).

## 1. The two registers

| | Ledger section | Story section |
|---|---|---|
| Heading | `## The ledger (machine-checked)` | `## The day's story` |
| Renderer | `build_journal` list literals (414-422) | `story_section` (292-367) |
| Content | integer counts over git log, checkin.md, timeline | deterministic prose paragraphs over feeds (telemetry.db, budget.md, plans.json, digest, beat-blockers.tsv, lessons) |
| Citation | none (the count IS the fact) | every paragraph preceded by `<!-- feeds: <source-list> -->` |
| Verified by `--check` | YES | NO (never parsed, never counted) |

Invariant (story_section docstring, line 296): story "Never touches the
ledger's format." The story's `journal_narrative` prose (the human arc above
the ledger) also carries no parseable counts and is not verified.

## 2. Ledger line grammar (exact, EBNF-ish)

Section contains exactly these four bullet lines in order, then the
fixed public-edition line:

```
ledger        = commits_line NL checkins_line NL timeline_line NL
                public_line NL
commits_line  = "- **" D+ "** commits; **" D+ "** candidate-bound"
                [ "; **" D+ "** labeled-excluded" ] "."
checkins_line = "- **" D+ "** check-in" ( "s" | "" ) " "
                ( "(none)" | ("#" D-1-9 { " #" D-1-9}) ) "."
timeline_line = "- **" D+ "** timeline rows: " ( "none" | kind { SP kind } ) "."
kind          = kindname "×" D+
kindname      = one of done | event | rotation   (sorted bytewise)
public_line   = "- Public edition: ~/.hngh/dispatch/" DATE ".md (same feeds, markdown)."
D             = digit ; D-1-9 = nonzero digit
```

Numbers equal, respectively: `len(day_commits(day))`, count of subjects
starting `hngh: candidate`, count containing `excluded from cert manifest`
(`day_stats`, 131-136); `len(day_checkins(day))` = check-in heading anchors
in `docs/project/checkin.md` (114-119); `len(day_timeline(day))` = rows in
`automation/state/timeline.tsv` with day match and kind in {done, event,
rotation} (121-128). Pluralization: `check-in`/`check-ins` and
`row`/`rows` switch at exactly 1; `candidate-bound` clause and
`labeled-excluded` clause are omitted only at value 0 (commit line keeps its
leading `- **N** commits` even at 0).

Canonical examples (emitted strings, verified byte-for-byte this session):
- `- **7** commits; **3** candidate-bound; **1** labeled-excluded.`
- `- **1** check-in #2.`
- `- **2** check-ins #2 #5.`
- `- **0** check-in (none).`
- `- **2** timeline rows: done×1 rotation×1.`
- `- **0** timeline rows: none.`

## 3. Story-line vs ledger-line classification

A line is a **ledger line** iff all of:
1. It appears under `## The ledger (machine-checked)` (between that heading
   and the next `## `).
2. It starts with `- **` followed by a decimal integer.
3. Its shape is one of the three grammar productions above.

Everything else is a story line (or structural). In particular these are
NEVER ledger lines even though some contain bold numbers or bullets:
- `journal_narrative` arc paragraph (prose, no `- **` prefix).
- story paragraphs and their `<!-- feeds: ... -->` citations (HTML comment,
  not a list item, contains no counted integer).
- `- \`sha\` mission line` commit bullets under `## The day's commits`
  (bullets but no `**N**` count).
- `dispatch_section` tables and the fixed `Public edition:` line (the
  checker never matches it; it is decoration, deliberately outside the
  grammar because `~/.hngh` is userspace, not repo state).

## 4. --check verification contract

`generate-publication --check [DATE]` (DATE defaults to today;
argparse 723, main 737-738; docstring 14-15: read-only, writes nothing).

Given `docs/journal/<DATE>.md`:
1. Recompute ground truth: `day_stats`, `day_checkins`, `day_timeline`.
2. Match exactly three regexes, anywhere in the file (they are anchored
   enough by their literal shape):
   - `- \*\*(\d+)\*\* commits`
   - `; \*\*(\d+)\*\* candidate-bound`
   - `- \*\*(\d+)\*\* check-in`
3. Exit codes:
   - `0` — all three matched AND parsed integers equal recomputed
     (commits == len(commits), candidate-bound == candidates,
     check-in == len(checkins)). Prints `journal <DATE> verified (...)`.
   - `1` with the "operator-authored format" message — any of the three
     regexes found no match: the file is not a machine-generated journal;
     the checker refuses rather than guesses. Message names the `- **`
     ledger lines explicitly.
   - `1` with the "drifted" message — all matched but some count differs;
     the message prints journal vs reality for commits and candidates.

Contract properties: read-only; fails closed (missing journal -> 1, missing
lines -> 1, mismatched counts -> 1); never inspects the story section (a
hand-edited story, even a wrong one, cannot pass or fail --check); the
timeline line and labeled-excluded clause are NOT yet verified (known gap,
see below). Test anchor: `automation/tests/test-narrative-ledger.py`
`test_daily_writes_journal_and_dispatch` (lines 232-267) asserts
`--daily --force` then `--check` returns 0.

## 5. Known gaps (candidates for future nodes)

- `--check` does not verify the timeline count line or the labeled-excluded
  clause, though both are machine-checkable.
- Regexes match anywhere, so a story line accidentally shaped like a ledger
  line would satisfy (or corrupt) the check; a section-scoped parse would be
  stricter.
- `day_stats` counts candidates by subject prefix only; `--check` re-uses the
  same source, so it is a regeneration-consistency check, not an independent
  audit.
