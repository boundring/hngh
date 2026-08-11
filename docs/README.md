# Hngh documentation

This is the working documentation surface. Read it before the archive.

## Start here

1. [`core/charter.md`](core/charter.md) — why Hngh exists, its scope, and who decides.
2. [`core/system-design.md`](core/system-design.md) — product boundary and stable architecture.
3. [`core/session-operations.md`](core/session-operations.md) — the 24 operating laws, session lifecycle, afterlife, and model economy.
4. [`core/delivery.md`](core/delivery.md) — work breakdown, active frontier, backlog intake, and gates.
5. [`core/records-and-governance.md`](core/records-and-governance.md) — record ownership, journal, archive, and retention rules.
6. [`records/2026-08-10-reorientation.md`](records/2026-08-10-reorientation.md) — this consolidation transaction and its preserved review boundary.

## Read order for an agent session

1. Read this file and `AGENTS.md`.
2. Read `core/delivery.md` and the current review record before selecting work.
3. Read only the linked legacy source required by the named task.
4. Check live claims and lanes before writing a shared surface.
5. Write evidence, handoff, and a journal record before retirement.

## Document classes

| Class | Authority | Location |
|---|---|---|
| Core | Current project rules and boundaries | `docs/core/` |
| Records | Current journal, backlog, manifests, decisions | `docs/records/` |
| Archive | Preserved historical plans, reviews, guides, and detailed material | `docs/archive/2026-08-10-pre-consolidation/` |
| Compatibility alias | Old path resolving to archive content | `docs/design`, `docs/project`, and related links |

An archive item can explain history. It cannot override a core document, a current review hold, an operator decision, or live evidence.

## Status vocabulary

- `DRAFT` — proposed; no execution authority.
- `DESIGN` — reviewed intent; implementation still needs a card and fixtures.
- `IMPLEMENTED` — code or configuration exists; behavior may still be unverified.
- `VERIFIED` — named evidence confirms the stated behavior at a stated point.
- `HOLD` — work must not proceed until the named gate clears.
- `HISTORICAL` — preserved evidence; not a current instruction.
- `SUPERSEDED` — retained for provenance; a named current record replaces it.

## Current delivery boundary

[`core/delivery.md`](core/delivery.md) is authoritative for the current
frontier. The planner-fixture review record is fixed historical evidence; a
correction or new review record, not a rewrite, changes its interpretation.
