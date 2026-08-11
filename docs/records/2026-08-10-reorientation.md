# 2026-08-10 — documentation reorientation

**Status:** complete
**Scope:** simplify Hngh's working documentation without changing source, runtime/workbench state, or the active planner-fixture review boundary.

## Starting facts

- The project had a large design/project/journal/research tree with overlapping current-state statements and historical priority lists.
- The canonical workbench roots are `~/.hngh/.hngh-night/` and `~/.hngh/.hngh-day/`; the former roots are compatibility symlinks. This transaction does not move runtime/workbench content.
- `tests/unit/test-hngh-planner.lisp` is an existing dirty review surface. It is excluded from this work.
- The fixed planner-fixture review is preserved at `docs/archive/2026-08-10-pre-consolidation/legacy-docs/review/project-review-2026-08-10.md`.

## Archive transaction

The old project documentation, root session records, root journal, and Hermes plans were moved without textual edits into `docs/archive/2026-08-10-pre-consolidation/`. The archive manifest records the source mapping, file counts, and content-set receipts.

Compatibility symlinks preserve documented and programmatic old paths. They are not part of the working documentation surface. An empty `.hermes/plans/` is the new scratch location for future Hermes planning; historical plans are archived.

## New working set

The new working surface is `docs/README.md` plus five documents in `docs/core/`:

1. charter;
2. system design;
3. session operations;
4. delivery system;
5. records and governance.

`docs/records/` holds dated transactions, the backlog, and consolidation manifests. New work starts there; archive sources are fetched only by a named task.

## Verification record

- 130 legacy documentation/session/plan files were moved into the dated archive.
- Content-set receipts, compatibility paths, and Git rename verification are recorded in `consolidation-manifest-2026-08-10.md`.
- No source, configuration, test, runtime, lane, or workbench file was changed by this record.
- No test result is claimed by this transaction.

Attribution: Hermes Agent — openai/gpt-5.6-terra via openai-api, Hermes TUI; cost unknown.
