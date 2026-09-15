# Journal

Dated working entries (`YYYY-MM-DD.md`), one per day, newest last. This
directory is part of the HISTORICAL tree: trust CURRENT docs for how
things work today; cite journal entries for how things got that way.

## Format invariant: no YAML frontmatter, H1 first

Every journal entry starts with its `# Journal — <date>` H1 heading as
the very first line. No file in this directory begins with a `---`
YAML frontmatter block. Tooling that extracts journal history can rely
on line 1 being the H1.

Check command:

```sh
! grep -rl --include='*.md' -e $'^---' docs/journal/
awk 'FNR==1 && $0 !~ /^# /{print "MISSING-H1:", FILENAME}' docs/journal/*.md
```

Output as of 2026-09-14 (21 files):

```text
$ grep -rl --include='*.md' -e $'^---' docs/journal/ | wc -l
0
$ awk 'FNR==1 && $0 !~ /^# /{print "MISSING-H1:", FILENAME}' docs/journal/*.md
(no output: all 21 files are H1-first)
```
