# 04 — The automation machine (hngh-automation)

<!-- MERGED 2026-10-13 from the 2026-08-30 doc suite, which lived
     outside version control (handoff §3.3). Provenance snapshot:
     paths and counts are as measured 2026-08-30. In particular
     `hngh-automation/` names a repo that has since merged into this
     one -- read it as `automation/`, and `~/Projects/etc/hngh` as the
     repo root. Facts that moved are fixed in place, not annotated. -->
Doc suite v1.2, 2026-08-30 (revised after adversarial audit) · part of the family indexed by [suite index](../core/README-architecture.md).
Evidence: repo sources read this session; live `systemctl --user list-timers`
(2026-08-30: all active, 0 failed).

## 1. What it is

The execution half of Hngh: bash + Python 3 stdlib scheduled by systemd
**user** timers. It runs the cadence (observe → review → research →
maintain → execute accepted plans), files evidence rows in the kernel's
report ledger, and lands its own work as plain gated commits. It depends on
the kernel; the kernel depends on nothing. One persistent background unit
of its own — `hngh-dashboard.service` (`dashboard-server.py`, :8890; see §6);
every other periodic thing is a systemd user timer pair.

## 2. Stack and dependencies

- bash + python3-stdlib only for all producers/consumers.
- npm deps are audit-only: `axe-core`, `puppeteer-core`
  (`package.json`, used by `jobs/ui-audit.mjs`).
- systemd **user** units; `make enable` installs/starts them, `make
  disable` stops all (Makefile 10-37).
- **No git remote** — hngh-automation is local-only by design; the sweep's
  push step is a no-op without an origin (`jobs/sweep-artifacts.sh` pushes
  only when a remote exists).

## 3. Cadence tiers

Every tier runs `jobs/cadence-tick.sh`, which executes that tier's
`cadence/<tier>/*.sh` drop-ins in lexical order (`cadence/README.md`).
Mounting work = dropping a `*.sh`. 28 drop-ins across 8 tiers (as of 2026-08-30):

| Tier | Unit(s) | Drop-ins (what) |
|---|---|---|
| 1m | `hngh-cadence-1m` | operator-items feed · sessions observatory feed |
| 5m | `hngh-cadence-5m` | time-ledger · system feed · oversight tick (probes + gated steer leg, loop recognition) · agent supervision |
| 10m | `hngh-cadence-10m` | evolve-ui (graded dashboard style evolution) |
| 30m | `hngh-cadence-30m` | readout spine · system/schedule/research/plan feeds · config-backup |
| hour | `hngh-cadence-hour` | dashboard self-review · ui-audit · workbeat · session-cost |
| day 05:00 | `hngh-cadence-day` | ledger prune (48h) · lesson harvest · activity tick · gate-check (both repos) · fresh-eyes review-prep · research beat · remote posture · budget digest · doc-suite check |
| week / month | Mon/1st 06:00 | roadmap review · zoom-out |
| 2h | `hngh-overnight` | executes **accepted plans** via omp-bridge delegated sessions |
| misc | — | security (4h) · credential-health (hour) · night-agent · night-research (23:40) · model bench (01:10) · morning (06:00) · morning report (07:30) · automation + autonomy (hour) |

17+ timer pairs in `systemd/` (18 hngh timers active as of 2026-08-30);
`make enable`/`make disable` install/stop all
of them (Makefile lines 10-37). Tier schedules (`cadence/README.md`):
1m `*:*:00` · 5m `*:0/5:00` · 10m `*:0/10:00` · 30m `*:00/30:00` ·
hour `*:00:10` (10s offset dodges the :00 storm) · week Mon 06:00 · month
1st 06:00. Gate: `make test` = `bash -n` sweep over all cadence/jobs/lib/
scripts + `scripts/lint-identifiers.sh` (heredoc-aware since 08-29);
end-to-end proof is `make smoke`.

## 4. What runs when (observed unattended)

```mermaid
timeline
  title One unattended day (33h window ending 2026-08-30T04:54Z)
  every minute : operator-items · session observatory tails
  every 5 min : time-ledger · oversight probes (loops, tree-skew, stale stores) · agent supervision
  hourly : sweep-artifacts commit+push · dash self-review · ui-audit · workbeat · autonomy heartbeat
  every 30m : feeds (readout/system/schedule/research/plan) · config-backup
  05:00 day : prune (48h) · gate-check both repos · fresh-eyes review · research beat · remote posture · budget digest
  every 2h : overnight cycle — accepted-plan execution via omp-bridge sessions
  07:30 : morning report
  09:00 : morning digest
```

Proven in the 33h window ending 2026-08-30T04:54Z: one 8-step plan executed
to green on both gates; 4 research lines crystallized (~1h each); ~40 sweep
commits; 0 failed units; honest $0 remote-spend row (`reports.md` `f5929eaa`).

## 5. The overnight cycle

`scripts/overnight-cycle.sh` (2h timer): pick the next **accepted** plan →
per-step delegated omp sessions via `omp-bridge --run-start` (budget loadout)
→ agent supervision watches (a stalled *bridge* run is closed-and-replaced
in-tick; transcript stalls are advisory) → landing: plain gated commits in
hngh-automation, certificate ceremony in hngh → steps that cannot meet
their verification park with operator-facing alerts and the cycle moves on.
Research lines are the sanctioned filler; the machine never idles on a human
(`docs/records/2026-08-28-automation-advancement.md`).

## 6. State surfaces

| Surface | Path | Shape |
|---|---|---|
| Breadcrumbs (every tick) | `STATE.md` (grows unboundedly; 4.1MB / 37,915 lines as of 2026-08-30 — see R3) | `{ts}\|{job}\|{event}\|{detail}`, `¦` escapes pipes |
| Alerts/progress | kernel `docs/project/reports.md` + `report-bodies/` | append-only, identity+window dedup (×N bumps) |
| Daily narratives | `digest/` (day, REVIEW, RESEARCH-BEAT, MORNING, BENCH) | REVIEW slims to findings + reviewed ranges (865B vs 118.9KB) since 08-29 |
| Dashboard feeds | `dashboard/*.json` + `telemetry.db` (SQLite WAL) | atomic writers as of 2026-08-30 fix `760adb5` |
| Run records | `bridge/record.lisp` (+ rotated `bridge/<ts>-<run>/`) | live delegation ledger |
| Plans | kernel `docs/project/plans/*.plan.md` | header `<!-- plan: status=… risk=… accepted=… -->` + step checkboxes |

## 6.1 Jobs catalog (`jobs/`, 30 scripts as of 2026-08-30)

Feeds: `sessions-feed.py` (observatory + transcript tails),
`schedule-feed.py` (recurring + oneoff lanes with the p50→loadout→default
estimate chain), `research-feed.py`, `plan-feed.py`, `system-feed.py`,
`readout` (`cadence/30m/05-readout.sh`), `operator-items-feed.py`,
`kb-feed.py`, `telemetry.py` (SQLite WAL emit), `telemetry-report.py`
(readers), `time-ledger.sh`.
Watchers: `oversight-tick.sh` (probes + gated agentic steer leg),
`agent-supervision.py` (transcript phase classifier; bridge-run roguelike
replacement; staleness eviction as of `5b79b86`), `dashboard-self-review.py`
(two-tier findings), `ui-audit.mjs` (axe-core + register rules; corpus
re-read before filing as of `dcb6221`), `security-check.sh`,
`credential-health.sh`, `sweep-artifacts.sh` (hourly artifact commits),
`cadence-tick.sh` (tier runner; allowlist of tiers), `lint-identifiers.sh`
(gate; heredoc-scoped since the 08-29 repair), `doc-suite-update.sh`
(daily doc-suite verifier, day tier). Surfaces: `dashboard-server.py`
(:8890). Catalog abridged — 30 scripts total as of 2026-08-30
(`ls jobs/` for the full list); the missing ~10 are utility jobs
(`agent-watchdog.sh`, `config-backup.sh`, `daily-writeups.sh`,
`morning-digest.sh`, `night-research.sh`, `ping-hourly.sh`,
`refresh-dashboard.sh`, `session-cost.py`, `system-awareness.sh`,
`window-tile.py`, …).

## 7. Gates

- `make test` — bash -n sweep over all shell + `lint-identifiers`
  (heredoc-scoped identifier tracking; caught a real bug: the deck's
  `$DESKTOP_IP` splices never expanded inside a quoted heredoc tag).
- `make smoke` — end-to-end proof: real fetches + real model call +
  dashboard HTTP check.
- Day-tier `03-gate-check.sh` gates **both** repos since the 08-29 plan
  (rows `ad39f093` kernel 2,855 checks + `f92dc864` automation green);
  gate-red rows are escalated by the 5m oversight tick (identity-scoped,
  hourly cap).
- Hourly `make sweep` commits job artifacts (append-only surfaces) with the
  sweep's own breadcrumb; the tree stays clean by construction.

Cross-links: [06-observability.md](06-observability.md) ·
[08-refactor-investigation.md](../project/08-refactor-investigation.md) ·
`hngh-automation/digest/TRIP-STATUS-2026-08-28.md` (operator stop commands).
