# 2026-09-07 -- P2 repo merge: automation subtree imported; guard cured for parentless commits

## The change

Phase 2 of the repo-merge plan
(docs/design/repo-merge-consideration.md): hngh-automation imported into
this repo as `automation/` via `git subtree add --prefix=automation
../hngh-automation master --squash` (merge
`b881186`, squash root `826d5a5`). P1 quarantine had already landed in
both repos: the tracked set imported clean (222 files, zero machine
data), hngh's `automation/`-prefixed gitignore entries cover the
regenerating paths, and `git status --short automation/` is empty.
The subtree's internal fetch briefly pulled the automation history's
objects in as unreachable; `git gc --prune=now` restored the pack to
4.04 MiB. `make test` and `make -C automation test` both green.
P3 (path-reference rewrite), P4 (systemd units), P5 (old remote
retirement) remain queued and were not attempted.

## The contradiction the import exposed

`make test` failed immediately after the import: the loop-history
guard test crashed with exit 128 on `git diff 826d5a5^ 826d5a5`.
`git subtree add --squash` lands the imported tree as a PARENTLESS
root commit ("Squashed 'automation/' content from commit 453f9dc"),
so `{sha}^` does not resolve. Worse, diffing that root against the
empty tree lists the imported paths UNPREFIXED -- the automation
tree's own `scripts/` and `Makefile` sit at the top level -- so the
root nominally "touches" the code surface and the guard would flag it
even without the crash.

## The cure (this candidate)

`tests/scripts/test-loop-history-guard.py`, guard policy unchanged:

1. `diff_base(sha)` resolves the commit's real parent via
   `git rev-list --parents -n 1` and falls back to the empty tree
   (`4b825dc6...`) for parentless commits -- no more crash.
2. Subtree-squash roots (subject matching
   `^Squashed '.*' content from commit [0-9a-f]+$`) are skipped
   structurally: their content is judged at the merge commit, where
   the paths land under `automation/` and touch no code-surface
   prefix. This is a rule, not a named exemption, so future subtree
   imports are covered.

Guard after cure: 81 code-surface commits checked, 0 violations;
`make test` rc=0 with the candidate commit in history.

## Verification

- `git ls-files automation | grep -E 'machine-data paths'` -> empty.
- `git status --short automation/` -> empty.
- `.git` pack 4.04 MiB after gc (was 4.8M total pre-import).
- `make test` rc=0; `make -C automation test` rc=0
  (ttsr-fit contract passed, lint-identifiers clean).
