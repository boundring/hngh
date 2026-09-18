# Megastructure vision — 2026-09-18 (operator directive, flavor-forward)

## Jev as the city planner

Jev's context window is the constraint and the gift: whole-system state
MUST compress to a compact abstraction or intent dissolves. Proven live:
a 4-key state dict (beats/beads/unsloth/queue) answers a system-level
Noul in ~1s (`calm` = 0.12, system correctly not calm). The state schema:

- `beats`: held/active + guard layers landed
- `beads`: closed/open counts + hot lanes
- `unsloth`: server load + operator-active verdict
- `queue`/`roadmap`: Next pointers only, never full contents

Intent survives because questions carry it ("calm enough to resume?")
while state carries only facts. New pattern: every beat writes its
4-key line to a state file; Jev reads the file, never the repo.

## The map: Hngh as Nihei megastructure

Existing surfaces: dashboard TUI (:8890, graded 10/10), ui-evolve
overlay presets, manga panel pipeline (sample/latest/panel outputs).
The map grows from these, not instead of them.

Districts (subsystems as city zones):

- The Tiers: cadence tiers as vertical strata, 1m at the surface down
  to month in the deep dark. Beats as elevator traffic.
- Bead Boroughs: open beads as construction sites with scaffolding,
  closed beads as finished nested blocks. Stale beads gather rust.
- The Unsloth Furnace: the local model server as a glowing industrial
  core. Operator-active = the furnace door barred from outside.
- Typesafe Lanes: tram-lines of fast inference, 2/min local cars plus
  the parked 10/sec expressway.
- The Pipes: steam (logs), food (digests), raw materials (research
  lines) flowing between districts. Creatures in the pipes optional
  but encouraged.

Growth engine: procedural, driven by live state. Every closed bead
adds a block. Every record adds a plaque. The city starts as one pipe
on bare rock (today) and grows toward planet-scale as the backlog
drains. Bruno-figure optional: a tiny safeguard silhouette walking
the deep strata would be a fine easter egg, kept small and kind.

## Supply (what feeds the builders)

Ideas (operator vision), inference (cheap models + Jev reflexes),
roles/squads (omp roster beads), style seeds (manga collection as
texture library, Dorohedoro mess at the seams, Blame! verticality in
the tiers). Supply maps to visible structure: more closed beads,
more city. Stalled lanes show as quiet dark streets, not errors.

## First buildable slice

Static export: a script reading `bd list --json`, queue/roadmap Next,
timer states, and emitting one JSON city-state + one SVG district map.
No engine, no 3D yet. File: `automation/jobs/city-state.py`. Tracked
as bead hngh-city-slice.
