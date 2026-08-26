# Interface plan — the needs-first contract for Hngh's command center

Status: planning artifact (ceremony-ready). Source: operator directive 2026-08-26
(`backlog.md` rungs `Command center — CLI + GUI operator surfaces`, `Machine-steered
backlog`, `Webapp dashboard`, `Hosted agentic interface`, `System awareness rung`,
`OMP↔Hngh bridge plugin`, `Agent live view`), the adversarial newcomer review of the
live dashboard (`http://127.0.0.1:8890`, 5 prioritized fixes), and operating
precepts 1–11.

This is the **contract** both interfaces must satisfy — not a spec or a design. It
ranks what an operator MUST see/do first ("needs first"), names the exact data
source per readout, names the exact control + the governing gate per action, and
orders the work into small slices. Nothing here adds features; it only makes
existing surfaces honest, on-demand, and controllable.

---

## 1. Operator needs — ranked

What an operator MUST see/do to use Hngh as a command center, needs-first.
Each is tied to the backlog rung it unlocks.

### Must

| # | Need (what the operator must see/do) | Rung it unlocks |
|---|---|---|
| M1 | **See a real health verdict at a glance** — one honest line ("all clear," what changed), with state colors legend and no raw-count alarms. | Webapp dashboard (review fixes 2, 5) |
| M2 | **See surfaces only on demand** — open the dashboard/session host explicitly; nothing auto-pops or auto-launches. | Webapp dashboard |
| M3 | **See the live schedule and the real Next** — next queued item with honest ordering, never fabricated `ETA` times. | Command center (+ gantt only once real dates exist) |
| M4 | **Summon an agent for any purpose** — type an ask and have a worker run fire through the existing admission lane. | Hosted agentic interface, OMP↔Hngh bridge |
| M5 | **Ask for an improvement and see it considered** — the ask is contrasted with existing features and slotted; **and expedite it** with the acceleration + cascading-delay ripple visible. | Machine-steered backlog + Command center |
| M6 | **Preside over subagents** — a live view (working/idle/parked) alongside the main instance with the power to PAUSE and NAME the unwanted behavior. | Agent live view + Hosted agentic interface |
| M7 | **See system awareness** — host CPU/mem/disk/net + model-endpoint + fleet, read-only, feeding a steer suggestion on change. | System awareness rung |

### Nice (built after Must; fewer, cheaper)

| # | Need |
|---|---|
| N1 | Navigable, auto-tiling session views (a tmux-like tiling of Hngh runs) — *after* real session-hosting (M4) proves the need. |
| N2 | A consumable **journal / daily narrative** pane over the raw records and check-ins. |
| N3 | Multiple dashboard dialects (gantt-port dials: circular, spiral) + the `--dance` delight layer — display-only, never data-affecting. |
| N4 | Trending/historical readouts (per-section history from the dashboard snapshots) once the base readouts are trusted. |

## 2. The awareness contract — what the command center shows, and where it comes from

Every at-a-glance readout MUST be sourced from an existing spine; nothing derived
by hand. `REUSE` = already present (just surface/markup); `FIX` = present but
mislabeled/incomplete; `NEW` = named here as the gap to build.

| At-a-glance item | Shows | Data source (exact) | Status |
|---|---|---|---|
| Health verdict | one-line status + color legend (define `evacuated`=finished & detached) | `dashboard/data.json` → `digest` block; `system.json` `headroom` booleans | REUSE, FIX (promote verdict first; legend states) |
| Active work now | mounted slice / running run | `readout.json` `sessions`+`roster`; `data.json` breadcrumbs (`mounted`, `running`) | REUSE |
| Next + ordering | next queued card + real `Depends on`/`ordering` | `readout.json` `queue`+`etas`; `docs/project/queue.md` `## Next`; `rotate-queue` state | FIX (rename `ETA`→ordering; truncation) |
| System resources | CPU/mem/disk/net %, model endpoint health, fleet peers, headroom flags | `system.json` (356/extension); `fleet-manager --discover`; `probe-model-route` | REUSE (system.json warm); expose & freshness-stamp |
| Subagent status | working/idle/parked per attached session, beside the main instance | `readout.json` `roster`; hngh store sessions + mounted agent transcripts | NEW (roster exists; live state + labels gap) |
| Reports | digest/actions summary ("For the operator") | `data.json` `digest`; `docs/project/reports.md` | REUSE (newcomer-readiness fix 5) |

Freshness: every readout carries the timestamp of its source's last refresh
(`generated_at` on `system.json`/`data.json`); a stale pane is labelled `stale
(Nm)`, never silently re-derived.

Single verdict rule (M1/7): the dashboard shows ONE health line (derived from the
latest digest + headroom), then the numbers — the counts are secondary, never the
headline.

---

## 3. The control contract — what an operator must be able to DO

Every action is an explicit operator request through an existing gate. `CLI`
verbs are additions to `scripts/hngh` (Lisp `dispatch-command`); `GUI` is a button /
field on the webapp (same command underneath — routed through the CLI).

| Action | CLI verb (in `scripts/hngh`) | GUI (webapp) | Governing gate |
|---|---|---|---|
| **Summon an agent** | `summon <purpose>` → `create-run` + `admit-transport` + `arm`/`start` | an "Ask Hngh" box → fires a run (visible in roster) | Run admission (`create-run`→`admit-transport`); a mutation flows through `issuecert` |
| **Schedule / rotate an item** | `schedule <id>` | the queue card's "Schedule" | `rotate-queue` (operator-owned, no-daemon timetable); the slice it performs is certificate-gated |
| improvement (K-oriented: considered + contrast + fit) | `ask <improvement>` | "Consider an improvement" | turns into an ADVISORY candidate (machine-steered selector ranks it and logs the choice in a report row); **any landing** rides the normal queue→card→proposal→verdict→`issue-cert`→`mutation-check` |
| **Expedite + see ripple** | `expedite <id> --by <n>` | "Expedite" + degree | read-only: computes new ETA + which scheduled items shift (acceleration + cascading delay); the actual reorder rides `rotate-queue` |
| **Pause a misbehaving subagent** | `subagent pause <roster-id>` | roster "Pause" | a control-plane steer to the watchdog/handoffs ledger (advisory, no mutation); the run's own mutation remains cert-bound |
| **Name the unwanted behavior** | `subagent flag <id> "…"` | "Name behavior" | recorded as an observation/steer feeding the corrective action; a correction lands only via `issue-cert` |
| **Open / close surfaces on intent** | `dashboard` / `dashboard close` | open (explicit click or timer-wired trigger) | Never auto-popup; "no daemon" held |

Every control is immediate and echoes how the ask was decided (a short report
row) so the operator sees *why* something was slotted or shifted, matching the
machine-steered-backlog "choice + reasons land in a report" contract.

---

## 4. Build order — small slices, needs-first, no daemon until the bridge proves it

Each slice is a small, check-in-scale-ish commit; none is optional before the next
in its line, and the Must slices (S1–S7) precede the nice ones. Nothing below introduces a
daemon.

| Slice | Deliverable (observable) | Rung |
|---|---|---|
| S1 **Truth-telling dashboard** | webapp: one honest health verdict first, state color legend, `ETA`→`Depends on` rename, reorder-by-usefulness. Reuses the readout spine + digest only. | Webapp dashboard |
| S2 **System awareness panel** | webapp + CLI show CPU/mem/disk/net + model endpoint + fleet, freshness-stamped, read-only; a resource change yields a steer/alert, never a hidden action. | System awareness rung |
| S3 **CLI status verb** | `scripts/hngh status` prints the spine: verdict, active lane, next-ordered queue, roster — a real command-center read in the terminal. | Command center (read side) |
| S4 **Live roster panel** | webapp renders working/idle/parked subagents beside the main session, refreshed by the existing watch loop; opens on demand. | Subagent view (M7) |
| S5 **Summon control** | `summon` + web ask-box fire a run through `create-run`→`admit-transport`; the run appears in the roster. | Hosted interface + bridge |
| S6 **Consider + expedite + ripple** | `ask`/`expedite` produce a justified-candidate report with acceleration + cascading delay; nothing mutates except through the gates. | Machine-steered backlog + Command center |
| S7 **Pause + label** | roster "Pause" + "name behavior" reach the watchdog/handoffs ledger; a flagged behavior triggers a corrective steer. | Subagent view + hosted interface |
| S8 **Hngh-as-app** | OMP↔Hngh bridge plugin (sided adapter, omp keeps structure, fail-closed) + hosted run/session as the default surface; **only here** may a daemon be justified, and it stays an on-demand session host. | OMP↔Hngh bridge + Hosted agentic interface |

(The S4/S7 slices map one-to-one onto the single "subagent view + pause + label"
review trigger of the command-center rung.)

---

## 5. What we deliberately do NOT build yet — and one-line why

- **Dancing/dynamic `--dance` UI + multi-style gantt dials (spiral/circular/clock
  rings)** — delight, not a need; the command center must read data before it
  dances.
- **A long-run daemon / always-on hosted service** — the "no daemon" boundary
  holds; hosting stays an on-demand session host until the bridge rung proves its
  need (per the command's Risk note).
- **Fleet pool / multi-machine resource gantt (resource-pool-view)** — M7 reads
  local + tailscale peers; pooling treats a later need, not a newcomer one.
- **Self-optimization continuum full loop** (self-modifying cadence/timer rules)
  — arrives only after a command center exists and the advisory→certificate path is
  proven; nothing changes a timer rule without a ceremony today.
- **Surface-evolution auto-grading loop for the dashboard** — keep style changes
  via informed check-ins until the readouts are trusted and the base surfaces
  stable.
- **Full daily journal prose pipeline (journal-daily) as a build target** — N2 is a
  thin pane over existing logs; a separate pipeline is over-engineering until the
  pane is consumed.
- **Fabricated schedule dates / ETA algorithm** — we show real ordering and ghost
  queue rows with ETA tooltips only when a real date exists (honesty fix S1); a
  predictive ETA estimator is a deferred nice.

---

### One-line disposition

Reuse the watchdog / oversight / webapp readout spine; reuse the run-admission +
certificate gates as the only mutation/control path. Every slice continues to the
gates as already existing; steering and labels follow the nervous-system
control-plane precept (#7) and model-tiering (#10) — cheap-local planning, gated
advanced work where the cadence can afford it.