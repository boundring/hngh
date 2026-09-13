# 2026-09-13 -- governed-fleet-consolidation: the operator ratifies the
# stages 3+4 merge; roadmap, backlog triage, and slices A-G become the
# landing contract

## Operator ratification (2026-09-13)

The operator ratified docs/design/governed-fleet.md as drafted, with
these explicit terms (normalized from the ratification message):

- Approval: "the operator approves the Governed Fleet consolidation as
  drafted and accepts all four section-9 losses."
- Amendment (operator's words, normalized): "the visibility demotion
  (gantt/medians losing stage anchor) is accepted in exchange for a
  modern operations-visibility surface -- the operator named 3D
  knowledge graphs as the flavor." The operator directed recording a
  new named slice (slice G, operations knowledge-graph surface) or a
  stage-6-lane item, "whichever your section-7 Now/Next edit
  accommodates more honestly": an interactive 3D graph view of hngh's
  operations (nodes = registries, chain legs, services, packages,
  credential seams, sessions, research lines; edges = the
  admission/consumption relations from the section-2 registry table),
  fed live from the existing registries + telemetry db, rendered in
  the existing dashboard (WebGL/three.js class), graceful fallback to
  a 2D/static view when WebGL is unavailable. "It is NOT exit-bearing
  (the ten invariants stand unchanged) -- it is the operator-directed
  replacement for the demoted visibility framing."
- Execute order: the ratification is the explicit go for
  `scripts/omp-bridge --propose` and the certificate-ceremony landing.

Slice G was placed in stage 3's slice list (governed-fleet.md section
6), not the stage-6 QoL lane: it visualizes exactly the registries
this stage admits, so it belongs where they are defined. The draft's
section 9.1 records the acceptance; the plan and the roadmap Now/Next
edits carry the slice.

## The four accepted losses (governed-fleet.md section 9)

1. Visibility de-pinned: stage 3's written "gantt renders actual bars
   beside estimates; per-lane medians" is non-exit scope. Medians stay
   ledger rows; gantt actual bars stay slice C scope; slice G is the
   replacement surface.
2. Stage 4 scope loss: maintenance routines (orphans, caches, journal
   vacuum) and "CachyOS first, per-host orientation generalizes" drop
   from the stage (defer to stage 7 / SMALL lanes); the governed
   upgrade exit is kept.
3. Config-lanes exit already true (config-lanes.tsv +
   hngh-cadence-30m.timer, hngh-automation 34cd275): carried as a
   standing invariant (section 4.9), not forward work.
4. Stage 7 loses the first-admission precedence: one peer is admitted
   in stage 3; stage 7 keeps orient + backup + fleet scale-out.

Item 6 of section 9 remains open by design: master-plan.md (dated
2026-08-26) still needs its one-line P5-adjacency amendment; it is not
part of this landing.

## What was ratified

- One stage replaces stages 3+4: "The Governed Fleet" (stage 3 keeps
  the number; the gap at 4 is honest history). Scope, ten invariant
  exit criteria, and the registry/guard/patrol/certificate pattern are
  as written in docs/design/governed-fleet.md.
- Sequencing: slices A (bili S1-S3, telemetry.py before model.sh),
  B (spawn-path matrix), C (witnessed cycle + seeded stall
  auto-replace), D (governed package upgrade), E (credential-seam
  sweep), F (node-lattice admission -- the federation exit), G
  (operations knowledge-graph surface; never exit-bearing).
- Backlog triage per governed-fleet.md section 8 (ABSORB / DROP /
  DEFER).

## What lands now

- Plan governed-fleet-consolidation
  (docs/project/plans/2026-09-13-governed-fleet-consolidation.plan.md),
  risk=normal, ten steps (slices A-G + ratification/roadmap step +
  backlog flips + done-flip gate).
- docs/project/roadmap.md: the merged stage-3 row replaces the former
  stage-3 and stage-4 rows; merge footnote under the table; Now
  paragraph; Next working-order items 2-3 rewritten; the stale
  history clause (worker-driver E2E and node-lattice amendments roll
  into stage 3 and stage 7) corrected to stage 3. Stages 0-2 and 5-7
  stay verbatim; the no-daemon line stays (transient per-run service
  posture).

## Ceremony

The record, the roadmap edit, the draft, and the plan land through
`scripts/omp-bridge --ceremony` (flock/timeout wrapper over
scripts/ceremony-drive): create-run -> admit-transport -> propose
(deterministic ten-principle verdict) -> issue-cert + mutation-check
prepare-candidate -> issue-cert + mutation-check commit ->
certificate-gated push. The commit message is the certificate's
content hash ("hngh: candidate <hash>"). Ceremony outputs and the
commit hash are in the session report; the git log is the durable
anchor.
