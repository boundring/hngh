# Architecture index — what we want, where it is designed, queued, and recorded

This is the single hub that maps Hngh's **system-harness intent** (the
fleet-governance ambition) onto its concrete homes: the promotion rungs in the
[roadmap `## Now`](project/roadmap.md), the
[system-harness rungs A–F](project/system-harness-roadmap.md), the rotation
state in [queue.tsv](project/queue.md), the proposal prose in
[backlog.md](project/backlog.md), and the verified facts in
[records](records/README.md).

The [architecture charter](architecture.md) remains the canonical "what the
kernel is" document; this file only *indexes* where intent is carried
(design → queue → record), never replaces it.

Reading rule: **a queue.tsv id is the rotation handle; its proposal prose
lives under the matching heading in backlog.md; the "Record" column names the
dated record that preserves the verified outcome.**

## System-harness rungs A–F

The harness vision (a fleet of nodes under one governance) climbs rungs A–F
in [system-harness-roadmap.md](project/system-harness-roadmap.md). Rung A's
groundwork is the promotion-rung 11–18 surface already landed and verified in
`## Now`.

| What you want | Where it is designed | Where it is queued (queue.tsv id) | Backlog entry (backlog.md) | Where its record lives |
|---|---|---|---|---|
| **A — node lattice** (pinned admission before pooling; in place) | system-harness rung A; promo rungs 11–18 | `node-lattice-admission`, `wake-mutation-lane` (next rotation), `bridge-operator-host`, `key-rotation-freshness` | Node-lattice admission rung; Certificate-bound wake lane; Bridge-as-operator-host | `2026-08-24-design-distributed-attestation`, `r12`, `r14`, `r15`, `r17-wake-peer`, `r18-worker-transport` |
| **B — resource pool view** (one panel, each node a row) | system-harness rung B | `pooled-hardware`; `resource-pool-view` is queued-once (below) | Resource pool view; Device fleet bring-up | `2026-08-26-continual-scheduling` (fleet-manager) |
| **C — component-level status / dance-able surfaces** | system-harness rung C; `ui-grades` + `dancing-ui` | `ux-hardening`; `gantt-ports` (interface-expansion) | Gantt ports; Dancing interfaces; Operative overlay; UX/interface pass | `2026-08-26-osd-and-dashboard`; `design/interface-grading.md`, `design/operative-frames.md` |
| **D — agentic continuous config** (declared, evidence-backed, reversible) | system-harness rung D (mutation executor + worker substrate) | `config-manager` (backlog; not yet a queue row) | Config manager | future (name scope, evidence command, observed result) |
| **E — security-manager duties** (key freshness, hygiene, patch state) | system-harness rung E; dep rung B | `key-rotation-freshness`, `credential-rotation-auto` | Security manager; Evidence-freshness + key-rotation rung | `key-rotation-freshness` (queued) record |
| **F — steady benchmarking** (parameterized per-node runs into the ledger) | system-harness rung F; worker-run substrate (`r18-worker-transport`) | `governance-benchmark` | Governance-benchmark research lane | `2026-08-25-r18-worker-transport` (substrate) |

**The five harness rungs named for queuing** (system-harness-roadmap
"Review-indexing"): `resource-pool-view`, `config-manager`, `security-manager`,
`notify-agent`, `ci-governance-gate` all have backlog entries (same ids) but are
**not yet queue.tsv rows** — they must queue through the backfill-queue rotation
step before any governance binding.

## Autonomy continuum — roadmap `## Next` rung 2 (8 directives)

The operator directive 2026-08-26 folds the hourly cadence into a
self-governing continuum with **no daemon**: every tier stays an
operator-installed timer invoking single-tick scripts.

| Intended rung (directive) | queue.tsv id | backlog.md heading | Record / surface |
|---|---|---|---|
| Both repos push their own verified commits; origin never lags the ledger | `push-self-sufficiency` | Push self-sufficiency (autonomy continuum) | `2026-08-26-post-ceremony-push` |
| Token/key rotation, health probes, alert reports, zero operator | `credential-rotation-auto` (folds into `key-rotation-freshness`) | Credential rotation automation | 2026-08-26 13:00Z token-refresh FAILED (STATE.md) |
| Timing tiers as systemd units over single-tick jobs | `cadence-continuum` | Cadence continuum | `design/activity-matrix.md` tier schedule |
| Routine project activities on the tiers, fleet-scaled | `activity-cadence` | Activity cadence | `2026-08-26-activity-cadence`; `project/activity-matrix.md` |
| Relax ritual/ceremony terms to flexible governance vocabulary | `governance-vocabulary` | Governance vocabulary | `2026-08-26-governance-vocabulary` |
| Automatic live view of working subagents in the dashboard | `agent-live-view` (folds into `ux-hardening`) | Agent live view | `2026-08-26-agent-live-view` |
| Evolutionary design/development for operator surfaces | `surface-evolution-loop` (extends `dancing-ui` + grade-interface) | Surface evolution loop | `2026-08-26-osd-and-dashboard` |
| Hngh picks its own best next course continually (course-selection step) | `machine-steered-backlog` | Machine-steered backlog | `2026-08-26-course-selection` |

Operator directives outside the 8-rung frontier (queued in backlog, waiting on
the above mounts): `webapp-dashboard` (browser dashboard, never auto-launch)
and `self-optimization-continuum` (a standing self-review that emits
`optimize: <suggestion>` breadcrumbs; nothing changes its own timer definitions
without a ceremony).

## P2 DESIGN contracts

The four P2 design contracts (2026-08-27) close the command-center,
awareness, buddy, and gamification designs; each is ceremony-ready and
gates a build phase in the [master plan](project/master-plan.md).

| Contract | Covers | Gates |
|---|---|---|
| [Command center architecture](design/command-center.md) | CLI+GUI center over one spine, S1–S8 mapping, control & awareness contracts | P3 (S1–S5), P4 (S6–S8) |
| [System awareness map](design/system-awareness-map.md) | probe architecture, `system.json` flow, flap-suppressed alerts, headroom thresholds | S2 / system awareness rung |
| [Pixel-RPG buddy menu spec](design/buddy-menu-spec.md) | summoned non-nagging overlay, quest ask, state→animation mapping, QML6 delivery | P6 operative surface |
| [Gamified-run model](design/gamified-runs.md) | runs-as-stories events, roguelike death rule, honesty leash | P6 gamification |

## Legend

- **queue.tsv id** — rotation handle in [queue.tsv](project/queue.md); `id <tab> status <tab> title <tab> evidence` rows; `status` advances `queued → active → done`.
- **backlog.md heading** = the proposal prose (Problem / Smallest useful outcome / Evidence / Risk / Dependencies / Review trigger) for that same id.
- **A, B, C…  = system-harness rungs** in [system-harness-roadmap.md](project/system-harness-roadmap.md); numbered rungs = promotion rungs in the [roadmap `## Now`](project/roadmap.md) `Completed` list.
- Every mutation behind any of these still rides the existing certificate gates; none of A–F nor the continuum admits a daemon. The index is a display/ledger artifact, never an authority.