# Command center architecture

Status: DESIGN — P2 contract, 2026-08-27. Ceremony-ready.

Source: [`../project/master-plan.md`](../project/master-plan.md) (spine
facet, phased roadmap, immediate next actions), the
[`../project/interface-plan.md`](../project/interface-plan.md) needs-first
contract (M1–M7, S1–S8), the 2026-08-26 operator directive (backlog rungs
`Command center — CLI + GUI operator surfaces`, `Machine-steered backlog`,
`Webapp dashboard`, `Hosted agentic interface`, `System awareness rung`,
`OMP↔Hngh bridge plugin`, `Agent live view`), and the adversarial newcomer
review of the live dashboard.

Cross-links: [`../core/clean-architecture-charter.md`](../core/clean-architecture-charter.md),
[`../core/component-map.md`](../core/component-map.md),
[`presentation-boundary.md`](presentation-boundary.md),
[`../project/roadmap.md`](../project/roadmap.md),
[`../project/decisions.md`](../project/decisions.md).

## Vision

One command center presides over Hngh as **system harness** (governing
hardware, software, network) and **agentic harness-harness** (governing
the harnesses that run agents). The center is two surfaces over one
spine: a CLI (`scripts/hngh` verbs) and a GUI (webapp + optional desktop
overlay), both rendering the same pure readouts and routing every action
through the same existing gates. There is no second core: the command
center is presentation plus dispatch over the kernel, nothing more.

## Operating precepts held

- **Reads are pure.** Every readout derives from an existing spine
  (`system.json`, `data.json`, `readout.json`, `docs/project/queue.md`,
  the report ledger, the operator store). Nothing is derived by hand and
  nothing hides which fact it came from.
- **Steers are advisory.** A resource change, a stale lane, a flagged
  behavior produce a report/alert or a steer suggestion — never a hidden
  action.
- **Applies are certificate-gated.** Any mutation rides
  propose → issue-cert → mutation-check through `ceremony-drive` or the
  operator gates. The command center never bypasses a gate.
- **No daemon until the bridge proves it.** The webapp serves on demand;
  surfaces open explicitly; the only justifiable daemon is the P4
  on-demand session host, and it waits for S8.
- **Presentation is display-only.** Renderers follow
  [`presentation-boundary.md`](presentation-boundary.md): canonical terms
  stay canonical, `perceptual` narrative never enters control input.

## S1–S8 mapping

The S slices are the command center's build order; each is a small,
check-in-scale-able commit against an existing rung.

| Slice | Deliverable | Surface | Reuses / touches |
|---|---|---|---|
| S1 Truth-telling dashboard | one honest health verdict first, state color legend, `ETA`→`Depends on` rename, reorder-by-usefulness | webapp | `dashboard/data.json` digest, readout spine |
| S2 System awareness panel | CPU/mem/disk/net + model endpoint + fleet, freshness-stamped, read-only | webapp + CLI | `system.json`, `fleet-manager --discover`, `probe-model-route`; see [system-awareness-map.md](system-awareness-map.md) |
| S3 CLI status verb | `scripts/hngh status` prints the spine: verdict, active lane, next-ordered queue, roster | CLI | `dispatch-command` read verbs, presentation renderers |
| S4 Live roster panel | working/idle/parked subagents beside the main session, on demand | webapp | `readout.json` roster, watch loop |
| S5 Summon control | `summon` + web ask-box fire a run through `create-run`→`admit-transport`; visible in roster | CLI + webapp | run admission gates |
| S6 Consider + expedite + ripple | `ask`/`expedite` produce a justified-candidate report with acceleration + cascading delay; reorder still rides `rotate-queue` | CLI + webapp | machine-steered selector (P1 #1.5 `select-course`), report ledger |
| S7 Pause + label | roster "Pause" + "name behavior" reach the watchdog/handoffs ledger; flagged behavior triggers a corrective steer | webapp | watchdog/handoff ledger |
| S8 Hngh-as-app | OMP↔Hngh bridge plugin (sided adapter, fail-closed) + hosted run/session as default surface; only here may a daemon be justified, and it stays an on-demand session host | OMP plugin | omp-bridge, hosted interface |

S1–S5 are P3 DEV; S6–S8 are P4 DEV. S4 and S7 share the single
"subagent view + pause + label" review trigger.

## Control contract

Every action is an explicit operator request through an existing gate.
GUI buttons route through the same command underneath as the CLI verb.

| Action | CLI verb (`scripts/hngh`) | GUI (webapp) | Governing gate |
|---|---|---|---|
| Summon an agent | `summon <purpose>` → create-run + admit-transport + arm/start | "Ask Hngh" box | run admission; mutations cert-gated |
| Schedule / rotate an item | `schedule <id>` | queue card "Schedule" | `rotate-queue` (operator-owned timetable), slice cert-gated |
| Consider an improvement | `ask <improvement>` | "Consider an improvement" | advisory candidate; landing rides queue→card→proposal→cert |
| Expedite + see ripple | `expedite <id> --by <n>` | "Expedite" + degree | read-only ripple compute; actual reorder via `rotate-queue` |
| Pause a subagent | `subagent pause <roster-id>` | roster "Pause" | advisory steer to watchdog/handoffs ledger |
| Name unwanted behavior | `subagent flag <id> "…"` | "Name behavior" | observation/steer; correction only via cert |
| Open / close surfaces | `dashboard` / `dashboard close` | explicit open | no auto-popup; no daemon held |
| Read the spine | `status`, `present`, `select-course`, `list-pins` | panels | none (read-only) |

Every control echoes how the ask was decided in a short report row so
the operator sees *why* something was slotted or shifted — the
machine-steered "choice + reasons land in a report" contract.

## Awareness contract

Every at-a-glance readout carries the timestamp of its source's last
refresh; a stale pane is labelled `stale (Nm)`, never silently
re-derived. The GUI shows ONE health verdict first, then the numbers;
counts are secondary, never the headline.

| Readout | Shows | Exact source |
|---|---|---|
| Health verdict | one-line status + color legend | `data.json` digest + `system.json` headroom booleans |
| Active work now | mounted slice / running run | `readout.json` sessions + roster, `data.json` breadcrumbs |
| Next + ordering | next queued card + real `Depends on` | `docs/project/queue.md` `## Next`, `rotate-queue` state |
| System resources | CPU/mem/disk/net %, model endpoint, fleet peers | `system.json`, `fleet-manager --discover`, `probe-model-route` |
| Subagent status | working/idle/parked beside the main session | `readout.json` roster, operator store sessions |
| Reports | digest/actions summary | `data.json` digest, `docs/project/reports.md` |

## Inward dependency architecture

```
kernel (domain) → application/ports → presentation spine → surfaces
                                              ↑                ↑
                                     CLI (dispatch-command)  webapp / TUI / OSD
```

- The presentation spine (`src/presentation`) renders any application
  result to one factual string; it imports no adapter.
- The webapp and TUI are **pure readers over the presentation spine**:
  they consume `scripts/dashboard-readout --json` / `system.json` /
  report-queue and render. They never import adapters, never mutate the
  store, and never decide.
- The CLI is the dense read + control surface: every GUI action routes
  through its verb so one gate implementation serves both.
- The OSD/buddy overlay is a display-only skin over the same spine
  (see [buddy-menu-spec.md](buddy-menu-spec.md)); dialog copy is
  display-only by the honesty leash (see [gamified-runs.md](gamified-runs.md)).

## Non-goals

- Dancing dials, gantt ports, `--dance` delight layers — display-only
  after the base readouts are trusted.
- A predictive ETA estimator — real ordering first; fabricated dates are
  forbidden by honesty rules.
- Multi-machine resource pooling — local + tailscale peers only; pooling
  waits for the fleet rungs.
- Self-modifying cadence/timer rules — nothing changes a timer rule
  without a ceremony.
- Any daemon before S8, and S8's host stays on-demand.

## Open questions

- `summon` loadout defaults: which route/tool labels a summoned run gets
  by default (local first, escalate on refusal?).
- Roster "Pause" semantics across omp subagents: what exactly the
  watchdog/handoff ledger records, and what "corrective steer" fires.
- Whether `status` also renders the buddy/OSD state line (spine parity)
  or stays kernel-only.