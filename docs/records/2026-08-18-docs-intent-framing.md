# Task: intent and direction documentation framing record

## Scope

Documentation-only reframing. Rewrites the root `README.md`, the
documentation index, and the roadmap, and adds `docs/intent.md` as the
human-facing vision document. No source, test, gate, or runtime change.

## Decision

The active docs previously stated status and contracts but not why Hngh
exists or where it is going. The reframing recovers the original intent from
the archived pre-refactor plans (roguelike discipline as bounded, evidenced
runs; the cost-first intelligence ladder; Pi as a replaceable outer worker)
and expresses it in plain language for a reader with only a casual
understanding of computers:

- `docs/intent.md` leads with the canonical story — development as short,
  bounded cycles (plan, check, record, close) with a paper trail and a human
  final say — then covers the run lifecycle, the roguelike analogy (labeled
  as metaphor, not game), kernel guarantees, clean architecture, agents
  (Pi/oh-my-pi framed as future and under consideration, never installed or
  decided), cost discipline, a 13-term plain glossary, and a pointer to the
  roadmap.
- The root `README.md` adds What/Why/How/Where-it-is-going sections while
  keeping the four verify commands verbatim and the status honest (library
  plus fixture tests only; no daemon, adapter, CLI, or Pi worker).
- The roadmap gains a Direction section explaining why each rebuild rung
  exists (evidence before claims; permission re-checked at the moment of
  action; reviewers advise, never decide), keeps the completed frontier
  accurate, and retains the no-daemon admission line verbatim.
- The documentation index now names two audiences — humans read intent
  first, engineers and agents read contracts — with Intent as item 0.

Game terms appear only as a labeled analogy. Nothing unbuilt is implied to
exist.

## Evidence

- `docs/intent.md` (new, 154 lines), `README.md`, `docs/project/roadmap.md`,
  `docs/README.md` rewritten per the framing contract above.
- Archived intent sources consulted at
  `~/Projects/back/hngh/2026-08-17-hermes-plans/plans/` (roguelike
  development process, clean-architecture megastructure scaffold, run domain,
  application ports, autonomous development control, cost-first intelligence
  ladder) and `~/Projects/back/hngh/2026-08-11-pre-crystallized-refactor/`.
- `make test` still reports 8 reader guard checks plus 717 checks — the
  documentation change is source-neutral.

## Remaining unknowns

No new technical unknowns. The Pi/oh-my-pi worker decision, the read-only
evidence adapter, the mutation executor, and model-review adapters remain
future roadmap work, as recorded in `docs/project/roadmap.md`.
