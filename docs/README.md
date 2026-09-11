# Hngh documentation

This directory is the active working surface.

These documents serve two audiences. People read [Intent](intent.md) first:
it explains why Hngh exists and where it is going in plain language.
Engineers and agents then read the contracts, which freeze the facts of how
things work today. Intent frames direction; contracts pin down details.

For newcomers: read [README.md](../README.md) at the repository root first.

## Read in this order

> **Terminology.** "Nerve center" names the webapp surface; "command
> center" names the CLI+GUI family it belongs to
> ([design/command-center.md](design/command-center.md) is that family's
> hub). Both describe stage-2's one consolidation.

Start with the one-page snapshot - it is maintained by hand until the
weekly wiring lands, and says so:

- [State of the project](project/STATE-OF-PROJECT.md) - the five-minute
  portfolio read before step 0.

### Tier one - five minutes

0. [Intent](intent.md) - why Hngh exists and where it is going.
1. [Architecture](architecture.md) - the current kernel and planned
   boundary map.

### Tier two - the contracts (thirty minutes)

2. [Run contract](core/run-contract.md) - domain values, lifecycle, and
   refusals.
3. [Clean Architecture charter](core/clean-architecture-charter.md) -
   dependency direction and promotion rules.
4. [Component map](core/component-map.md) - responsibilities and public
   APIs.
5. [Test boundary](core/test-boundary.md) - fixture and gate rules.

### Tier three - governance and the route (the deep read)

6. [Autonomous development control](design/autonomous-development-control.md) -
   source-grounded principle, review, and mutation-certificate policy.
7. [Presentation boundary](design/presentation-boundary.md) - factual
   renderer and reference-lexicon limits.
8. [Roadmap](project/roadmap.md) - the ordered rebuild frontier.
9. [Decisions](project/decisions.md) - decisions already made.
10. [Backlog](project/backlog.md) - work not yet admitted.
11. [Records](records/README.md) - evidence, decisions, and cutover
    records; the prior state's retirement archive is covered there.
## After the contracts: four shelves

The operator-facing surface and the integrations roadmap read as
companions to the contracts above. One line per shelf says what the
shelf is for; every link keeps its original description.

> The governance vocabulary is deliberately flexible:
> prose freely uses governance, validation, acceptance, and admission
> (the former "ceremony"/"ritual" terms are relaxed, not fixed).
> `ceremony-drive` is a stable CLI name, not a doctrine - it names the
> closed governance loop's driver, and the token stays as-is even as the
> prose around it varies.

### Shelf one - operator interfaces

The surfaces you look at, and the grading loop that keeps them honest.

1. [Assistant interfaces](design/assistant-interface.md) - the operative
   layer (the dark-coat presence, aesthetic, voice, interface family).
2. [Operative frames](design/operative-frames.md) - the animation/frame
   spec behind `evolve-operative`'s generated operative.
3. [Pixel-RPG buddy menu spec](design/buddy-menu-spec.md) - the summoned,
   non-nagging operative overlay and its click-to-open menu.
4. [Gamified-run model](design/gamified-runs.md) - runs as stories, the
   roguelike death rule, and the honesty leash.
5. [Command center architecture](design/command-center.md) - the unified
   CLI + GUI command center (S1-S8) over one presentation spine.
6. [System awareness map](design/system-awareness-map.md) - the read-only
   probe architecture, `system.json` flow, and flap-suppressed alerts.
7. [Interface grading](design/interface-grading.md) - the automated
   grade loop (`grade-interface`) and the graded surface each interface
   must pass.

### Shelf two - governance, loop, and register law

How the machine governs itself, and the one register its surfaces
speak.

1. [The Descent](design/descent.md) - the six-station cyclical
   self-improvement loop: stations, invariants, falsifiable weekly
   checks, and the flavor-name lexicon.
2. [Bestiary](design/bestiary.md) - the five failure-cause classes,
   grounded in this project's own incident rows, with the routing
   table from cause to disposition.
3. [Gate inventory](design/gate-inventory.md) - every gate in one
   ledger: what each checks, what it refuses, and its current verdict.
4. [Display register](design/display-register-spec.md) - the one Nihei
   register law: voice, proportions, palette, perceptual-only aliases.
5. [Writing register](design/writing-register.md) - the prose law
   (Orwell/Leonard/Adams) for all operator-facing and machine-drafted
   text.
6. [The Mirror](design/operator-mirror.md) - the operator-coherence
   layer: operator intent as versioned, citable registers with a
   local-first model-exposure policy.

### Shelf three - machine-hall operations

The credential, context, and topology machinery that keeps the live
tier honest.

1. [omp-hngh integration](project/plans/2026-09-09-omp-hngh-integration.plan.md)
   + [plans contract](project/plans/README.md) omp plugin interface -
   the omp propose surface, MCP/plugin plan, and the 2026-09-09
   operator doctrine + service-account records.
2. [The Keyring](design/keyring.md) - the credential-rotation harness:
   mass password rotation with the password manager as the only secret
   holder.
3. [Data sovereignty](design/data-sovereignty.md) - the Portage:
   de-google export and rehoming to local devices + syncthing, under
   the Mirror's model-exposure policy and the Keyring's handle-only
   rule.
4. [The Compass](design/context-manager.md) - the context-manager
   design: measured baselines for what each surface loads, and the
   budget that keeps them honest.
5. [The Splice](design/ttsr-alignment.md) - the ttsr alignment design:
   how test-to-spec-review findings loop back without a watcher.
6. [Wiki surface](design/wiki-surface.md) - the Athenaeum: two-vault
   wiki topology and its continual-optimization cycle.
7. [Repo topology](design/repo-merge-consideration.md) - the
   automation-into-hngh merge consideration: both cases steelmanned,
   middle paths, migration mechanics, decision factors. No decision
   made. Companion: [clean reorientation](design/clean-reorientation.md) -
   the automation-tier cleanup plan: Track A (decision-independent
   cleanup, verified findings) and Track B (merge-gated topology),
   with the leave-alone doctrine.

### Shelf four - research and roadmap

Where the governance pattern binds outward.

1. [Integrations marketplace](project/integrations-marketplace.md) -
   where the governance pattern binds to CI, agent harnesses, ops, and
   security tooling.
2. [System-harness roadmap](project/system-harness-roadmap.md) - a
   fleet of nodes under one governance: resource pool, config manager,
   security manager.

---

Back to the [repository README](../README.md).
