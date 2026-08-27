# Acceleration wave — roguelike wrap, status verb, truth dashboard, register spec

Dated: 2026-08-27.

## Scope

Four parallel slices executed in one wave (three implementation owners +
one research beat), each verified independently and committed through
its own certificate loop:

- **Slice A — roguelike delegation wrap** (`scripts/omp-bridge`): new
  `--run-start` (create bounded builder run + `admit-transport :worker`
  under a persistent `OMP_BRIDGE_STORE`; loadout token/time limits are
  the delegated budget) and `--run-end` (client-validated
  `cancelled|evacuated|dead` → `close-run`). `HNGH_BIN` env seam for
  hermetic tests. Suite `tests/scripts/test-omp-bridge.py` (9 checks)
  wired into `make test`. Exit codes propagate the house 0/1/2/3
  protocol; no masking.
- **Slice B — interface-plan S3** (`scripts/hngh status`): verdict-first
  spine read. `all-clear` iff data.json digest `status == "ok"` AND every
  system.json headroom boolean holds; else `attention (<parts>)`; either
  source missing/malformed → `unavailable` (fail-closed). Panes:
  system/active/next/roster, each `unavailable` when its optional source
  (`HNGH_STATUS_*` env or `*status-*-source*` binding) is absent.
  `stale (Nm)` when a `generated_at`/`g` UTC-Z stamp is >10 min old.
  +37 kernel checks; `src/main.lisp` carries a minimal strict JSON
  scanner (the model adapter's helpers are unexported and opaque-pack
  numbers — documented in code).
- **Slice C — interface-plan S1** (`scripts/dashboard-readout`):
  verdict-first hero + state legend (`evacuated = finished & detached`),
  display-only `ETA` → `Depends on` rename (machine keys untouched),
  reorder-by-usefulness (active floats, otherwise stable), unified
  `stale (Nm)` pane labels (30 min live / 24 h committed spine),
  additive `verdict` key on `--json`. No emoji; dark-coat register
  preserved.
- **Slice D — display register research beat**
  (`docs/design/display-register-spec.md`): the Nihei register
  consolidated — voice/caption rules, gen-4 measured proportions,
  palette discipline, `perceptual:true` vocabulary table, dosage ladder,
  future grade-interface hooks. Indexing in the docs hubs landed with
  this commit.

## Evidence

- `sbcl --script tests/run.lisp` → 2851 checks passed (was 2814; +37
  from the status-verb suite).
- `python3 tests/scripts/test-omp-bridge.py` → 9/9;
  `test-run-autonomous.py` 7/7 (untouched);
  `test-dashboard-readout.py` + `test-dashboard-live.py` green (verdict
  truth-table, rename, ordering, staleness).
- `scripts/lint-parens.py` green on every touched .lisp file.
- CLI smoke: `HNGH_STATUS_SYSTEM=/nonexistent.json sbcl --script
  scripts/hngh status` → all panes `unavailable`, exit 0; `status
  extra` → exit 2.
- Main's independent post-wave review re-ran every gate and diffed all
  claims; all four executors stayed inside their owned-file contracts;
  no git operations by executors.

## Lessons harvested (llm-wiki)

- `hngh-storeless-cli-state-loss` — multi-process CLI flows need an
  explicit shared `--store` and a pre-created root.
- `subprocess-stub-seam-for-hermetic-tests` — env-overridable binary
  seam (`HNGH_BIN`) is the one-line testability pattern for
  subprocess-wrapping scripts.
- `cl-string-escape-literal-backslash` — CL string escapes are minimal;
  whitespace sets are character lists.
- `verdict-rule-drift-two-surfaces` — the verdict rule was implemented
  with two different source mappings (B: contract-named files; C: local
  spine approximation, licensed as a documented open question).
  Alignment lands with S2 wiring of the real system.json sources.
- `untracked-artifact tax` — 6,289 never-committed report-bodies made
  every `git status --untracked-files=all` scan (verify-candidate,
  ceremony evidence, watchdog, dashboard ticks) walk a 6,312-row tree;
  ignoring the directory cut porcelain rows 6,312 → 25 and removed the
  cross-tool contention that stalled a 4-manifest verify batch to
  144 s (single-run cost is ~0.2 s uncontended).

## Observed behavior

Delegated sessions can now be spawned and ended inside hngh governance
(`run-start`/`run-end`), the terminal shows one honest verdict on
demand, the dashboard leads with the same verdict rule, and the register
spec gives every future surface one aesthetic law. The kernel's
governance surface is unchanged; no daemon added.

## Remaining unknowns

- Verdict source alignment (C's local-spine approximation → S2's real
  system.json wiring).
- Concurrent delegated sessions sharing one bridge store reuse `run-1`
  (documented ponytail ceiling; per-session stores when needed).
- run-end cannot persist an operator note (kernel `close-run` has no
  note slot).