# Task: retire the archive gate and archive boundary framing

## Scope

Removes the active project's dependency on the external retirement archive.
Deletes the `make check-archive` target, the `HNGH_ARCHIVE_ROOT` contract,
and the archive-boundary framing from the active documentation. The archive
itself is not deleted; it remains operator-preserved outside the repository
as historical evidence. No source or test change; Makefile and documentation
only.

## Decision

The prior state was archived to preserve the basis of the refactor, not as a
runtime or documentation dependency. The refactor records now cover the
cutover; the active project's state and roadmap do not consult the archive.
Continuing to verify archive receipts had no operational meaning: nothing in
the active project reads, imports, or depends on the archive, and the
receipt check only re-asserted that the preserved bytes had not drifted.

So the project now documents its current state and treats the archive as
history:

- `make check-archive` and `HNGH_ARCHIVE_ROOT` are removed from the
  Makefile; `.PHONY` lists `test` and `verify-candidate` only.
- README, docs index, intent, test boundary, decisions, roadmap,
  CONTRIBUTING, and AGENTS.md no longer present the archive as a verifiable
  boundary or a read target. The archive is described once, as historical
  evidence only, and contributors are told nothing from it is imported back.
- Meaningful archive material (the hermes plans behind the intent document,
  the pre-crystallized harness vision) is harvested into the operator's
  separate llm-wiki knowledge base for reference, not into this repository.
- Records keep the full prior-state story: the crystallized cutover record
  and this retirement record remain the authoritative history.

## Evidence

- `Makefile`: `check-archive` target and `HNGH_ARCHIVE_ROOT` deleted;
  `make test` still reports 8 reader guard checks plus 1137 checks.
- `git diff` shows only the retired archive gate and the archive-boundary
  doc framing; no Lisp or fixture source changed.
- The on-disk archive at
  `~/Projects/back/hngh/2026-08-11-pre-crystallized-refactor/` is untouched.

## Remaining unknowns

None for the active project. If the operator later wants to consult the
archive, it physically remains at the archived paths; no gate or document
needs to exist for that.