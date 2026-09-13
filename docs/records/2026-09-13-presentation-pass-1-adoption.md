# 2026-09-13 — presentation pass 1: the direction adopted into the public face

Plan: docs/project/plans/2026-09-09-presentation-pass-1.plan.md (operator-
directed, accepted 2026-09-09). Direction doc:
docs/design/presentation-direction.md — classy, dry, witty; Nihei
architecture and Hayashida grime-warmth as texture, never cosplay. This
record is the close-out of the pass (plan step 5): what landed, where it
lives, and what stays on the horizon.

## What the direction is

docs/design/presentation-direction.md (2026-09-09) makes presentation a
first-class lane rather than an afterthought: hngh's public surfaces
should read like one author — a machine that knows it is strange and is
precise about it. Binding rules from the doc: no marketing register, no
emoji, no exclamation marks in public docs, at most one epigraph or
aside per document, and structure before decoration. Rungs 3-7
(dashboard character, node-graph navigator, WebGL environmental surface,
hot-swap GUI wrapper, the distribution) are recorded ambitions — this
pass shipped rungs 1-2 plus the flavor layer only.

## What landed (rungs 1-2 + flavor + spine)

The pass stretched across 2026-09-11 and 2026-09-12, several sessions,
one plan:

- README front door (plan step 1). Commits e141d7f (2026-09-11, public
  face P0: README rewrite, worked example docs/core/worked-example.md,
  integration section), db4ba75 and 23dd1fd (2026-09-12, pass-1 polish:
  two-sentence identity, truthful status, navigation table mirroring
  docs/README.md's read-order). The opening epigraph ("Somewhere below
  the ground floor, a machine keeps its own minutes") is the direction
  doc's register in one breath.
- Docs spine (plan step 2). Commit 8e3bfb4 (2026-09-11, P1 reading
  flow: index clustering, list discipline) then b865330 (2026-09-12,
  docs/README.md restructured into Start here / How it governs itself /
  The live machine / Records and history, each entry one descriptive
  line, book.md promoted to "the long-form record" entry).
- Flavor layer, guarded (plan step 3). Commit 23dd1fd (2026-09-12):
  one epigraph each at the heads of README.md, docs/README.md,
  docs/architecture.md, and docs/project/plans/README.md. Budget held:
  one per document, no more.
- Publication spine (plan step 4). Commits 3687c78 and 6bb8e66
  (2026-09-12): scripts/generate-publication's ebook mode now carries
  the 2026-09-09 records and the presentation direction in the spine;
  docs/publication/book.md regenerated with them. The 2026-09-11 daily
  journal verifies clean against git records (generate-publication
  --check 2026-09-11, exit 0).

## Verification shape

Each step's plan-file verification ran on its own surface: relative
link checks over README and docs/, the exclamation/emoji sweep (zero in
public docs, code comments exempt), and `make test` green per slice.
The gate for this record is the same: `make test` green, the record
cross-linked from CHANGELOG.md.

## What stays open

- The 2026-09-12 daily journal has drifted from git records (commits 15
  vs 121, candidates 1 vs 13 per generate-publication --check) — a
  regen or recount slice for a later session, not this record's scope.
- Rungs 3-7 of the direction doc remain recorded ambitions; future
  plans pick them up. This pass deliberately did not attempt them.
- The README front-door commit db4ba75 carried a stray non-English word
  in its subject (already recorded in
  automation/state/ocgo-agent-lessons.md, 2026-09-12); the prose itself
  is clean.

Related: docs/design/presentation-direction.md,
docs/project/plans/2026-09-09-presentation-pass-1.plan.md,
docs/records/2026-09-09-operator-flexibility-doctrine.md (the doctrine
that allows presentation work through the ceremony),
docs/publication/book.md (the long-form record).
