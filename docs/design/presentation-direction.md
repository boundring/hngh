# Presentation direction — a building that knows it is strange

Status: DESIGN — operator direction, 2026-09-09. This document is the
north star for hngh's public surface and interface ambitions. It obeys
the standard doctrine: outer presentation, kernel untouched; every rung
ships through the normal gates.

## The premise

Hngh is not a tool that wants to look like a startup. It is a machine
that lives in a basement and got surprisingly good at its job. The
presentation should read like BLAME! looks: vast inhuman structure,
quiet operators, humor kept dry enough to store near the machinery.
Dorohedoro contributes the grime-warmth — texture where polish would be
anonymous, grotesque charm where a design system would be beige. Dai
Dark contributes the deadpan: never wink at the reader; state the
absurd as fact and move on.

Voice rules (binding for all public text):

- Classy, dry, witty. No exclamation marks in documentation. No
  marketing register anywhere — if a sentence could appear in a cloud
  product's landing page, delete it and say what the thing does.
- Wit lives in precision, not jokes: a dry aside earned by an accurate
  sentence. A verb in the right place is funnier than a joke.
- Flavor references (Nihei architecture, Hayashida grime, the Deluxe
  appetite) appear as texture — epigraphs, section spines, names —
  never as cosplay. The project is not a fan work; it borrows posture,
  not plot.

## Rungs (each one a shippable surface)

1. **Front door** (near-term): root README as a designed first screen —
   what hngh is in two sentences, a truthful status block, navigation
   that goes somewhere, badges only where they report real state. The
   dry voice throughout. No badge rot, no emoji confetti.
2. **Navigable docs** (near-term): omp.sh-style human knowledge base —
   one canonical spine (docs/README.md read-order), cross-linked
   records, generated publication surfaces (journal, book, EPUB)
   promoted from a side directory to the actual entry point.
   `scripts/generate-publication` is the engine; the work is curation
   and spine design, not new infrastructure.
3. **Winamp-plus dashboard** (in flight): bezels today; character
   tomorrow. Skins as personas, LCD ticker with opinions, the operative
   sprite earning its walk cycle. Collision with the a11y findings is
   deliberate: character and compliance in the same pass.
4. **Node-graph navigator** (mid): the knowledge base as a traversable
   graph — records, plans, rungs as nodes; dependency edges; the
   dashboards' gantt engine already computes the layout data.
5. **Environmental surface** (long): WebGL 3D of the machine's actual
   topology — hosts, timers, sessions as navigable architecture, Nihei's
   megastructure as an honest diagram of the thing. Derived from live
   state, not decoration; a viewing gallery, not a game.
6. **Hot-swap GUI wrapper** (aspiration, the big one): hngh wraps
   arbitrary software in flexible, hot-swappable GUIs with arbitrary
   aesthetics and theming. The dashboard, skins, and wrapper are one
   subsystem: interfaces as configurations, swappable without restart,
   the same way plans are hot-swapped onto the queue.
7. **The distribution** (horizon): a hngh-flavored Linux distribution
   based on CachyOS — the machine's own OS, where the kernel's
   governance is the init-adjacent layer and the presentation tier is
   the desktop. Everything above is rehearsal for this.

## What this means for the near-term queue

Interface and presentation work is acceleration work (operator doctrine
§3): the surfaces that let the operator see and steer hngh compound
every other operation. The stalled-computer lesson of 2026-09-09 is the
pattern — presentation is not vanity spend; it is the operator's
instrument panel. Docs and dashboard slices ride the same fail-first
queue as everything else, with the same green-gate discipline.
