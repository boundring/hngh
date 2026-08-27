# Hngh documentation

This directory is the active working surface.

These documents serve two audiences. People read [Intent](intent.md) first:
it explains why Hngh exists and where it is going in plain language.
Engineers and agents then read the contracts, which freeze the facts of how
things work today. Intent frames direction; contracts pin down details.

For newcomers: read [README.md](../README.md) at the repository root first.

## Read in this order

0. [Intent](intent.md) — why Hngh exists and where it is going.
1. [Architecture](architecture.md) — the current kernel and planned boundary map.
2. [Run contract](core/run-contract.md) — domain values, lifecycle, and refusals.
3. [Clean Architecture charter](core/clean-architecture-charter.md) —
   dependency direction and promotion rules.
4. [Component map](core/component-map.md) — responsibilities and public APIs.
5. [Test boundary](core/test-boundary.md) — fixture and gate rules.
6. [Autonomous development control](design/autonomous-development-control.md) —
   source-grounded principle, review, and mutation-certificate policy.
7. [Presentation boundary](design/presentation-boundary.md) — factual renderer
   and reference-lexicon limits.
8. [Roadmap](project/roadmap.md) — the ordered rebuild frontier.
9. [Decisions](project/decisions.md) — decisions already made.
10. [Backlog](project/backlog.md) — work not yet admitted.
11. [Records](records/README.md) — evidence, decisions, and cutover records; the
    prior state's retirement archive is covered there.

### Interface and research reads

The operator-facing surface and the integrations roadmap read as
companions to the contracts above, after the core read order:

> **Terminology.** The governance vocabulary is deliberately flexible:
> prose freely uses governance, validation, acceptance, and admission
> (the former "ceremony"/"ritual" terms are relaxed, not fixed).
> `ceremony-drive` is a stable CLI name, not a doctrine — it names the
> closed governance loop's driver, and the token stays as-is even as the
> prose around it varies.

- [Assistant interfaces](design/assistant-interface.md) — the operative
  layer (the dark-coat presence, aesthetic, voice, interface family).
- [Interface grading](design/interface-grading.md) — the automated grade
  loop (`grade-interface`) and the graded surface each interface must
  pass.
- [Operative frames](design/operative-frames.md) — the animation/frame
  spec behind `evolve-operative`'s generated operative.
- [Command center architecture](design/command-center.md) — the unified
  CLI + GUI command center (S1–S8) over one presentation spine.
- [System awareness map](design/system-awareness-map.md) — the read-only
  probe architecture, `system.json` flow, and flap-suppressed alerts.
- [Pixel-RPG buddy menu spec](design/buddy-menu-spec.md) — the summoned,
  non-nagging operative overlay and its click-to-open menu.
- [Gamified-run model](design/gamified-runs.md) — runs as stories, the
  roguelike death rule, and the honesty leash.
- [Integrations marketplace](project/integrations-marketplace.md) — where
  Hngh's governance pattern binds to CI, agent harnesses, ops, and
  security tooling.
- [System-harness roadmap](project/system-harness-roadmap.md) — a fleet of
  nodes under one governance: resource pool, config manager, security
  manager.