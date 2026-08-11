# 20260805 — Test-loop optimization completed

## What

Completed the halted 20260804 squad's test-loop work and fixed the real bugs
it exposed. The fast suite is now the default gate.

## Verification (all real runs)

- `make test-fast` — 205/205 checks in ~2.6s (hngh-up 42, squad-dispatch 52,
  beans 62, model-runtime 49). EXIT 0.
- `make test-full` — 1406/1406 checks. EXIT 0. (Up from the claimed 1393:
  previously-stalling beans tests now run.)
- `make lint-counts` — clean after the lint now sums the fast suite.
- Commit: `b7a0289`.

## Squad work (20260804T150741Z-cheap) completed and verified

- Makefile: `test` -> `test-fast` -> `test-suite` (SUITE param, 15s timeout),
  per-package targets, `test-full: check`.
- model-runtime: `*skip-model-pull*` fence; llama.cpp missing-path fail-fast.
- squad-dispatch: explicit `git add -A` pathspecs excluding embedded state.git;
  .gitignore rules; pathspec regression test.
- Tests: with-mr macro binds the pull fence; fixtures default to no
  supervisor/resource-manager.

## Bugs found during verification (all fixed)

1. **Makefile run! form** — bare `(:hngh.hngh-up ...)` list in function
   position (missing quote) -> undefined-function at load. Now `dolist` over
   the suite list.
2. **%git ran outside the squad root** — no `:directory` on run-program, so
   relative pathspecs resolved against CWD. Added `:directory squad-root`.
3. **%atomic-write renamed dotfiles wrong** — SBCL `rename-file` merges the
   temp file's TYPE into an extensionless target: `.gitignore` -> 
   `.gitignore.129774`. Temp name now built with `make-pathname` (explicit
   NIL type).
4. **ANSI CL has no `\n` escape** — `"\n"` reads as the character `n`. The
   bean inbox append wrote a literal `n`, so every section boundary after the
   first became `n---`, breaking `%parse-inbox` splitting and cascading into
   spore sub-bean loss, cull misses, and fixture collisions. Fixed with
   `(string #\Newline)`.
5. **nreverse count footgun** — `:sub-bean-count (length planted-beans)`
   evaluated after `nreverse` mutates the list -> always 1. Capture the
   reversed list first.
6. **%find-role-dirs uiop signature** — `collect-sub*directories` is
   `(directory collectp recursep collector)`; collectp gates descent, so the
   old `t nil` call never visited subdirectories -> cull found no roles.
   collectp = always-t, recursep excludes state.git, collector checks inbox.md.
7. **lint-test-counts.sh** — parsed only the last "Did N checks" line (49);
   now sums all lines (205).

## Durable CL lessons (worth a skill)

- No C-style escapes in ANSI CL strings: use `(string #\Newline)`, `~%` in
  FORMAT, or `~~` for a literal tilde (and never `~/.optmem` inside a FORMAT
  control string — `~/` is the call-function directive).
- SBCL `rename-file` fills a missing destination type from the source.
- `uiop:collect-sub*directories` collectp gates both collection and descent.

Attribution: squad run 20260804T150741Z-cheap (deepseek-v4-flash via
openrouter); verification + fixes — deepseek-v4-flash-0731 via openrouter
(Hermes TUI).
