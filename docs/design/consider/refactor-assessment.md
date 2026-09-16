# Tech-debt vs refactor assessment: hngh -> Hnnghh (2026-09-15)

## Size

- Kernel src/ 8.5k LOC Lisp, tests/ 9.0k LOC (2,931+ checks). Well-tested, pure charter.
- Automation: 36.0k LOC Python (138 files) + 20.7k shell (170 files) + 6.3k dashboard JS/HTML. 9 cadence tiers (1m..month). Backlog 1,769 lines / 84 sections (7 still "queued 2026-08-2x/31"); queue.md has 1 active item plus dormant sections (dancing-ui, fleet observation, interface-spec candidates).

## Debt inventory

- Backlog: node-lattice-admission (DONE 09-15 via ceremony), doc-sync loop, plan-supply, bridge-as-operator-host, evidence-freshness, publication-lines-contract, ebook-inputs all queued 3+ weeks. bridge-operator-host mounted but never incremented ~19 days (zoom-adversarial #6).
- Zoom-adversarial (corrected): the headline "red gate all day" was stale gate crumbs (patrol.py newest-crumbs-wins, no TTL) - a hygiene defect, not a red gate. CI drift window closed by ceremony 2f9e618f. Still real: suppression-as-fix routing (routed != resolved), overnight-lead cause=unknown cancellations, stage-2 "landing" since 08-26, stage-5 exit criteria unwired, research "planned" rows churning without crystallizing.
- Stage drift: stages 2,3,5 all nominally open; stage 3 ten-invariants have no evidence of running; Descent adoption gate and Audit station "specified and not wired".
- Vestigial sampling: 5 random automation files each have 26-56 referencing consumers - automation is largely load-bearing, not dead code. The accretion is *process* weight: duplicate probes, meta-loops watching meta-loops (patrol -> gate-cure -> router -> dedup), dormant queue sections, 84 backlog sections for a one-operator system.

## Minimal core (Hnnghh keep/shrink/drop)

| Tier | Verdict |
|---|---|
| Ceremony loop (cert-gated kernel mutations) | KEEP AS-IS - hardest-won asset |
| Loop-history guard, patrol routes, report-queue, dashboard conventions | KEEP - proven, fixture-backed |
| Kernel ledger spine (8.5k LOC, 2,931 checks) | KEEP or port nearly verbatim |
| Research->disposition->knowledge pipeline | SHRINK - one line/one disposition path, no churn states |
| Memory (two-home split, ~/.hngh layout) | KEEP - interface is clean |
| Cadence: 9 tiers | SHRINK to 2-3 (hour/day/human) |
| Patrol/cure/router/dedup stack | SHRINK hard - replace suppression with expiry+escalation |
| Overnight-lead lane, agent-supervision stack | DROP pending root-cause |
| Backlog governance surface (84 sections) | DROP - replaced by a one-file queue |

## Refactor-vs-pivot factors

- Migration cost is low where it matters: kernel is self-contained (pure Lisp, no host deps), ~/.hngh data is layout-contracted and portable, jcode seams are documented skills/MCP. The expensive-to-rebuild assets (ceremony, gates, 2,931 tests) are exactly the ones worth carrying over rather than rewriting.
- Mid-pivot loss: dispatch/newspaper/manga userpace outputs pause; the evidence ledger continuity (the project's core identity) would fork.
- Strangler option is proven in-repo: governed-fleet already absorbed stage 4 this way. Hnnghh core could land as new tiers (one pipeline, 2-3 cadences, expired-not-suppressed alerts) while patrol/overnight/backlog machinery retires slice by slice.

## Assessment

The debt is not code rot; it is governance accretion around healthy code. A from-scratch Hnnghh would re-earn the ceremony and gates at full cost. Recommended: strangler refactor inside hngh - compact automation to the minimal pipeline, retire meta-loops, keep the kernel.
