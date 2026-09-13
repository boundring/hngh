# Hngh documentation

> The corridors are numbered. The lights are on in all of them.
> Mostly.

This directory is the active working surface.

These documents serve two audiences. People read [Intent](intent.md) first:
it explains why Hngh exists and where it is going in plain language.
Engineers and agents then read the contracts, which freeze the facts of how
things work today. Intent frames direction; contracts pin down details.

For newcomers: read [README.md](../README.md) at the repository root first.
The four sections below are the whole map; everything listed here is
reachable from the root README in two hops or fewer.

> **Terminology.** "Nerve center" names the webapp surface; "command
> center" names the CLI+GUI family it belongs to
> ([design/command-center.md](design/command-center.md) is that family's
> hub). Both describe stage-2's one consolidation.

> The governance vocabulary is deliberately flexible:
> prose freely uses governance, validation, acceptance, and admission
> (the former "ceremony"/"ritual" terms are relaxed, not fixed).
> `ceremony-drive` is a stable CLI name, not a doctrine - it names the
> closed governance loop's driver, and the token stays as-is even as the
> prose around it varies.

## Start here

- [README](../README.md) - the front door: what Hngh is, its status, and
  how to navigate.
- [State of the project](project/STATE-OF-PROJECT.md) - the five-minute
  portfolio read before step 0, with verified numbers between the
  `torch:begin`/`torch:end` sentinels.
- [Intent](intent.md) - why Hngh exists and where it is going.
- [Architecture](architecture.md) - the current kernel and planned
  boundary map.

## How it governs itself

The contracts and the loop that keeps mutation honest.

- [Run contract](core/run-contract.md) - domain values, lifecycle, and
  refusals.
- [Clean Architecture charter](core/clean-architecture-charter.md) -
  dependency direction and promotion rules.
- [Component map](core/component-map.md) - responsibilities and public
  APIs.
- [Test boundary](core/test-boundary.md) - fixture and gate rules.
- [Autonomous development control](design/autonomous-development-control.md) -
  source-grounded principle, review, and mutation-certificate policy.
- [Presentation boundary](design/presentation-boundary.md) - factual
  renderer and reference-lexicon limits.
- [The Descent](design/descent.md) - the six-station cyclical
  self-improvement loop: stations, invariants, falsifiable weekly
  checks, and the flavor-name lexicon.
- [Bestiary](design/bestiary.md) - the five failure-cause classes,
  grounded in this project's own incident rows, with the routing
  table from cause to disposition.
- [Gate inventory](design/gate-inventory.md) - every gate in one
  ledger: what each checks, what it refuses, and its current verdict.
- [Display register](design/display-register-spec.md) - the one Nihei
  register law: voice, proportions, palette, perceptual-only aliases.
- [Writing register](design/writing-register.md) - the prose law
  (Orwell/Leonard/Adams) for all operator-facing and machine-drafted
  text.
- [The Mirror](design/operator-mirror.md) - the operator-coherence
  layer: operator intent as versioned, citable registers with a
  local-first model-exposure policy.
- [Roadmap](project/roadmap.md) - the ordered rebuild frontier.
- [Decisions](project/decisions.md) - decisions already made.
- [Backlog](project/backlog.md) - work not yet admitted.

## The live machine

What the operator looks at, and the machinery keeping the live tier
honest.

- [Assistant interfaces](design/assistant-interface.md) - the operative
  layer (the dark-coat presence, aesthetic, voice, interface family).
- [Operative frames](design/operative-frames.md) - the animation/frame
  spec behind `evolve-operative`'s generated operative.
- [Pixel-RPG buddy menu spec](design/buddy-menu-spec.md) - the summoned,
  non-nagging operative overlay and its click-to-open menu.
- [Gamified-run model](design/gamified-runs.md) - runs as stories, the
  roguelike death rule, and the honesty leash.
- [Command center architecture](design/command-center.md) - the unified
  CLI + GUI command center (S1-S8) over one presentation spine.
- [System awareness map](design/system-awareness-map.md) - the read-only
  probe architecture, `system.json` flow, and flap-suppressed alerts.
- [Interface grading](design/interface-grading.md) - the automated
  grade loop (`grade-interface`) and the graded surface each interface
  must pass.
- [Presentation direction](design/presentation-direction.md) - the
  binding voice for README and docs presentation work; the arbiter of
  register for this spine.
- [omp-hngh integration](project/plans/2026-09-09-omp-hngh-integration.plan.md)
  + [plans contract](project/plans/README.md) omp plugin interface -
  the omp propose surface, MCP/plugin plan, and the 2026-09-09
  operator doctrine + service-account records.
- [The Keyring](design/keyring.md) - the credential-rotation harness:
  mass password rotation with the password manager as the only secret
  holder.
- [Data sovereignty](design/data-sovereignty.md) - the Portage:
  de-google export and rehoming to local devices + syncthing, under
  the Mirror's model-exposure policy and the Keyring's handle-only
  rule.
- [The Compass](design/context-manager.md) - the context-manager
  design: measured baselines for what each surface loads, and the
  budget that keeps them honest.
- [The Splice](design/ttsr-alignment.md) - the ttsr alignment design:
  how test-to-spec-review findings loop back without a watcher.
- [Wiki surface](design/wiki-surface.md) - the Athenaeum: two-vault
  wiki topology and its continual-optimization cycle.
- [Repo topology](design/repo-merge-consideration.md) - the
  automation-into-hngh merge consideration: both cases steelmanned,
  middle paths, migration mechanics, decision factors. No decision
  made. Companion: [clean reorientation](design/clean-reorientation.md) -
  the automation-tier cleanup plan: Track A (decision-independent
  cleanup, verified findings) and Track B (merge-gated topology),
  with the leave-alone doctrine.
- [Integrations marketplace](project/integrations-marketplace.md) -
  where the governance pattern binds to CI, agent harnesses, ops, and
  security tooling.
- [System-harness roadmap](project/system-harness-roadmap.md) - a
  fleet of nodes under one governance: resource pool, config manager,
  security manager.

## Records and history

Evidence, decisions, and the long-form record.

- [Records](records/README.md) - evidence, decisions, and cutover
  records; the prior state's retirement archive is covered there.
- [The book](publication/book.md) - the long-form record, generated
  from the git/timeline spine by `scripts/generate-publication`.

---

Back to the [repository README](../README.md).
