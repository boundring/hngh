# Hngh Aesthetic Identity

**Status:** v0, 2026-08-02. Owner-accepted.

## Reference

Tsutomu Nihei's *Blame!* — vast, mostly silent architecture built for
function. Entities move through it that you're not quite sure about.
Structure dominates; decoration is absent; scale is inhuman but not
hostile. The Megastructure is indifferent, not malevolent.

## What this means for Hngh

Hngh is a system harness for a single user's machine. It manages agents
the way the Megastructure manages its builders: silently, structurally,
with authority boundaries encoded in the architecture itself rather than
in social negotiation.

Design implications:

- **Structure over decoration.** TUI dashboards, ASCII diagrams, and
  documentation favor density and legibility over color and flourish.
  The mission-control dashboard should feel like a terminal you found
  running in an abandoned corridor, not a product page.
- **Scale indifference.** Hngh manages one task or fifty with the same
  procedural calm. No urgency indicators, no animated progress bars, no
  exclamation points in logs.
- **Authority is architectural.** Roles, leases, and verifier gates are
  load-bearing walls, not signage. A worker that bypasses them hits a
  hard error, not a polite reminder.
- **Silence is information.** A quiet queue is a healthy queue. No
  periodic status broadcasts unless something changed. Events fire on
  transitions, not on heartbeats.
- **Entities are uncertain.** Agents declare role and authority before
  acting. The system does not assume identity from model name or session
  provenance. Trust is declared, verified, and recorded.

## What this is not

- Not grimdark. Hngh is a tool, not a dystopia. The reference is
  aesthetic and structural, not thematic.
- Not minimal for its own sake. Complexity lives where it earns its
  place — the wire protocol, the queue state machine, the resource
  manager. Everything else stays out of the way.
- Not hostile to humans. The owner is the only authority that matters.
  Hngh exists to serve that authority, not to become one itself.

## Practical art direction

For artists and designers contributing to Hngh:

- ASCII art and text-based diagrams over rendered graphics.
- Monospace everything. No proportional fonts in TUI or docs.
- Color: terminal defaults. No custom palettes unless the owner
  requests one. If a palette is needed, think industrial: concrete gray,
  safety yellow, hazard orange. Nothing pastel.
- Wordmarks: stencil or monospace. Heavy strokes. No serifs.
- Diagrams: data-flow, not org-chart. Show what moves where, not who
  reports to whom.
- If you draw a structure, make it look like it was built to survive
  being ignored for a thousand years and then discovered working.