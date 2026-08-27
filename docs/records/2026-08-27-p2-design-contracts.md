# P2 DESIGN contracts — command center, awareness, buddy, gamification

Dated: 2026-08-27.

## Scope

Stood up the four foundational P2 DESIGN artifacts in `docs/design/`,
each ceremony-ready per the [master plan](../project/master-plan.md)
immediate-next-actions item 3 and the honest-layering rules:

- `docs/design/command-center.md` — unified CLI + GUI command center
  over one presentation spine; S1–S8 slice mapping; control contract
  (every action through an existing gate); awareness contract (every
  readout sourced + freshness-stamped); webapp/TUI as pure readers.
- `docs/design/system-awareness-map.md` — read-only probe architecture
  (CPU/mem/disk/net, model endpoint, fleet), the
  `jobs/system-awareness.sh → dashboard/system.json → oversight-tick.sh
  flap-suppressed alerts → agentic steer attention` flow, headroom
  thresholds, and fail-closed degradation rules.
- `docs/design/buddy-menu-spec.md` — pixel-RPG summoned non-nagging
  overlay: click-to-open quest ask / toggles / shortcut lenses,
  state→animation mapping, QML6 delivery polling `/tmp/hngh-osd.json`
  over the existing `osd-operative` feeder, honesty rules.
- `docs/design/gamified-runs.md` — runs-as-stories model: the closed
  event vocabulary (`quest`/`victory`/`setback`/`reward`/`death`)
  derived only from real run fields, the roguelike death-and-
  replacement rule, and the `perceptual:true` honesty leash keeping
  narrative out of governance and selection inputs.

Indexing: `docs/architecture-index.md` gained a `## P2 DESIGN
contracts` table; `docs/README.md` read order lists the four.

## Evidence

- All four docs pass link resolution (every relative markdown link
  resolves) and were written with no trailing whitespace per house
  rules.
- `python3 scripts/verify-candidate.py` gate applied at ceremony time
  via `scripts/ceremony-drive` (certificate-bound manifest).

## Observed behavior

P2's exit criteria (ceremony-ready docs, open questions closed) are
met: each doc names its source, its cross-links, its non-goals, and
its open questions; none adds executable capability or a daemon.

## Remaining unknowns

- The open questions each doc records (summon defaults, roster pause
  semantics, probe cadence tier, lens set, character naming, setback
  narration) are closed in the build slices they gate, not here.