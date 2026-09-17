# generate-publication git-log spine — inventory (node hist-gitlog-b)

Date: 2026-09-15. READ-ONLY inventory; no repo files edited. Builds on
sibling artifacts hist-gitlog-dedupfmt-shape.md (entry JSON shape),
hist-windows-git.md (window spec), hist-journal-format.md (journal context).

## 1. Where the spine lives

Single producer call site in `scripts/generate-publication`:

- `git()` helper at line 92-95: `subprocess.run(["git", *cmd], cwd=ROOT,
  text=True)` returning `(rc, stdout, stderr)`.
- `day_commits(day)` at lines 103-111 — the ONLY git-log invocation in the
  script and the whole git-log spine:

```python
git("log", "--format=%s%x09%h", f"--since={a} 00:00:00",
    f"--until={b} 00:00:00")
# parsed as: [(subject.strip(), sha.strip()[:7]), ...]
```

Args and format facts:

- Format: exactly TWO fields, `%s` (subject) TAB (`%x09`) `%h` (abbrev sha).
  No `%H`, no `%an`, no `%aI` date field. Tab is the established in-repo
  separator (0/500 recent subjects contain a tab, per sibling shape spec).
- Window: one calendar LOCAL day, `--since=<day> 00:00:00` /
  `--until=<day+1> 00:00:00` (via `day_bounds`, lines 99-101). This is
  per-day, unlike the sibling spec's trailing-7d window; the two coexist as
  different consumers of the same repo history.
- NO `--no-merges`, no path filter, no author filter, no cap: merges and
  every commit in the window are included, unfiltered.
- Post-processing: subject `.strip()`ed; sha re-truncated to 7 chars via
  `sha[:7]` (this repo's native `%h` is 8 chars — the sibling shape spec
  already flags this as a second abbreviation convention a new producer
  should not copy).
- Failure mode: `git log` nonzero rc raises `RuntimeError("git log failed")`
  (fail closed at line 108-109). Malformed rows (no tab) are silently
  skipped by the `partition("\t")` guard — single-field lines drop out.

## 2. Consumers of the spine

`day_commits` feeds three surfaces, all inside generate-publication:

1. `day_stats(day)` (line 131): counts commits, `hngh: candidate <sha>`
   commits, and `"excluded from cert manifest"`-labeled ones — the
   machine-checked ledger numbers in the journal header.
2. `build_journal(day)` (line ~421): emits the journal section
   "The day's commits" as `- `<sha7>` {mission_line(subject, sha)}` bullets.
   `mission_line` (line ~456) rewrites candidate commits into
   `candidate <sha7> — <record title>` by scanning `docs/records/*.md` for
   the full hash; no citation yields an honest placeholder ("no mission
   line in records").
3. `check_day(day)` (line ~467, `--check` mode): re-derives the same
   counts and verifies the journal's stated `- **N** commits /
   candidate-bound / check-ins` lines; drift exits 1 (so the git-log spine
   is self-verifying against the committed journal).

The `--site`/ebook modes do NOT touch git log; `--site` reuses
`scripts/dashboard-readout` `data_spine()` (a different feed source).

## 3. Volume cost (measured live, 2026-09-15)

Row format = `subject<TAB>sha7\n`. Recent daily windows:

| window (00:00-24:00) | rows | bytes |
|---|---|---|
| 2026-09-14 | 233 | 22,234 |
| 2026-09-08 | 47 | 3,982 |
| 2026-09-01 | 1 | 90 |

A 7-day span (`--since=2026-09-08`, no until): 773 rows, 68.9 KB total;
row length median 84 chars, max 550. Cost is trivial at per-day scale
(<25 KB/day) and still small even at 7 days (~70 KB raw text, before any
JSON shaping). Runtime is milliseconds (single `git log` subprocess,
no object bloat; measured < 0.2 s wall). So the git-log spine imposes no
practical volume constraint; payload size concerns in the sibling cap spec
(400 entries, ~150-200 KB) are dominated by summary text length, not by the
spine's own overhead.

## 4. Mapping to the proposed history/1 producer

What the existing spine gives vs what the sibling shape spec needs:

| sibling-spec field | current spine | gap |
|---|---|---|
| `key` `gitlog:<40-hex>` | only `%h` (8) truncated to 7 | need `%H` (full) added to format |
| `ts` `%aI` Z-normalized | NOT extracted (day window implies date) | add `%aI` |
| `summary` | `%s` verbatim (stripped) | OK |
| `author` `%an` | NOT extracted | add `%an` |
| `short` 8-char `%h` | 7-char re-truncation | drop the `[:7]` |

Proposed spine upgrade is therefore one format string:
`--format=%H%x09%h%x09%an%x09%aI%x09%s`, identical window semantics (or
the sibling trailing-7d window), keeping the existing tab convention and
fail-closed rc check. `--check` mode's count-verification would keep
working unchanged since it counts rows, not fields.

## 5. What I did not check

- Whether any other script duplicates this spine (I grepped
  generate-publication only for call sites; dashboard-readout's
  `data_spine()` was confirmed not to use git log).
- Historical (pre-2026-09) row-length distribution beyond the 7d sample.
