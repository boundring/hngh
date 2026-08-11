# 2026-08-11 — card 127 planner quota truth

Scope: make the planner's general quota gate consume the quota ledger's derived pacing rather than supply caller-controlled zero elapsed time.

## Accepted result

`%quota-gate-open-p` now calls `quota-general-ok-p` without `:used 0` or `:elapsed-seconds 0`. `quota-general-ok-p` defaults its elapsed value to `:derive`, which makes `quota-ok-p` compute each bucket's elapsed time from persisted reset anchors while holding the quota lock.

The new `planner-quota-gate-derives-live-pacing` fixture writes half-window anchors, records one measured use, and proves that the planner gate opens from live pacing. The prior implementation fails that fixture because a zero elapsed value grants no pacing share.

## Write boundary

- `hngh.asd`
- `src/plugins/hngh-planner.lisp`
- `src/plugins/quota-spreader.lisp`
- `tests/unit/test-planner-quota-admission.lisp`

The accepted dirty fixture `tests/unit/test-hngh-planner.lisp` was not edited. The integration test copied its exact reviewed diff into an isolated worktree only; byte comparison confirmed it was unchanged.

## Verification

1. RED: the new fixture produced 60/61 passing checks and failed only because `%quota-gate-open-p` returned false.
2. GREEN: manually loading the changed source produced 61/61 passing checks in `:hngh.hngh-planner`.
3. Fresh-cache integration: `XDG_CACHE_HOME=<temporary cache> FAST_TEST_TIMEOUT=300 make test` passed. The selected suite reports 301/301 checks, including the 61-check planner suite; every selected FiveAM suite passed, and the Python linter fixture reported 4 passed.
4. `git diff --check` passed. AST diagnostics reported zero errors and zero warnings for both changed source files and the new fixture.

## Lesson

ASDF's shared compiled-output cache can execute a stale same-named source file from another worktree even when the current worktree's `.asd` is selected. A meaningful isolated verification uses a fresh per-worktree cache or manually loads the changed source. The default 15-second fast-test timeout also cannot accommodate a cold dependency cache. This belongs to the crystallization test-purity work; it is recorded as backlog intake I-007, not silently accepted as normal.

No remote model call was made. Attribution: Hermes Agent — openai/gpt-5.6-terra via openai-api, Hermes TUI; cost unknown.
