# 09 — Runbook

Doc suite, 2026-08-30 · part of [README.md](README-architecture.md). Operations cheat
sheet — grounded in `hngh-automation/digest/TRIP-STATUS-2026-08-28.md`
(still accurate) plus the 2026-08-30 fixes.

## 1. Health checks

```bash
systemctl --user list-timers 'hngh-*'      # all tiers; expect 0 failed
cd ~/Projects/etc/hngh-automation && make test   # bash -n sweep + identifier lint
cd ~/Projects/etc/hngh && make test              # kernel, 2,855 checks, ~35-39s
cd ~/Projects/etc/hngh-automation && make smoke  # end-to-end: real fetches + model + dashboard HTTP
cd ~/Projects/etc/hngh && scripts/schedule-heartbeat --dry-run   # queue/plan probes, no mutation
cd ~/Projects/etc/hngh && scripts/probe-model-route --route=auto # model route probe
```

## 2. Where things land

| What | Where |
|---|---|
| Alerts/progress rows | `hngh:docs/project/reports.md` (+ bodies `report-bodies/`, 48h prune) |
| Breadcrumbs | `hngh-automation/STATE.md` |
| Day digests | `hngh-automation/digest/` (REVIEW / RESEARCH-BEAT / MORNING / day narrative / BENCH) |
| Dashboard | `dashboard-server.py` on :8890; feeds in `dashboard/*.json` |
| Telemetry | `hngh-automation/dashboard/telemetry.db` |
| Plan execution record | the plan file's own checkboxes + status front-matter |
| Bridge runs | `~/.hngh-automation/store/run-*`, records in `hngh-automation/bridge/` |
| History | `hngh:docs/records/` (certificate-landed) |

## 3. Stop / start everything

```bash
systemctl --user stop hngh-cadence-{1m,5m,10m,30m,hour,day}.timer \
  hngh-overnight.timer hngh-automation.timer hngh-autonomy.timer \
  hngh-security.timer hngh-credential-health.timer hngh-night-research.timer \
  hngh-night-agent.timer hngh-model-bench.timer hngh-morning.timer \
  hngh-morning-report.timer
# restart: start in place of stop; week/month timers left running by default
# blunt alternative: cd ~/Projects/etc/hngh-automation && make disable
```

Services are oneshots; timers are the switches. Dashboard service:
`hngh-dashboard.service` (:8890).

## 4. Gates and verification

- Kernel: `make test` (2,855 checks, ~35-39s). Lint: `python3
  scripts/lint-parens.py <files>` after Common Lisp edits (repo rule).
- Automation: `make test`; end-to-end `make smoke`; ad-hoc tier tick:
  `make adhoc TIER=30m`.
- Kernel commits: **only** via ceremony-drive with a green gate;
  hngh-automation: plain gated commits; automation repo has **no remote**
  (local-only by design — adding one is an operator decision).

## 5. Daily reading order

1. `digest/MORNING-<date>.md` — world + machine morning line.
2. `digest/REVIEW-<date>.md` — fresh-eyes findings (slim since 08-29).
3. `hngh:docs/project/reports.md` — alert rows since last read (bodies in
   `report-bodies/`).
4. `digest/<date>.md` — the day's narrative.
5. Plan files — status front-matter + checkboxes.

## 6. Known dormant items (operator decisions)

- **GLM remote leg**: place `~/.hngh-automation/openrouter.token` to
  activate; until then `probe-model-route --route=auto` resolves local
  (proven green). No agent ever copies credentials.
- **omp-bridge refusal cause** (alert `a1fde252` lesson): kernel-src
  change — operator-directed session, failing-test-first.
- **hngh-automation remote**: none exists; `make sweep` pushes only when an
  origin exists (`jobs/sweep-artifacts.sh:30`).
- **Remote access to this box**: `sudo tailscale serve --bg 8890` remains
  deliberately operator-only (`docs/records/2026-08-28-lessons-consolidation.md`
  lesson 9).

## 7. Key in-flight state (as of 2026-08-30 05:30Z)

- Kernel HEAD `667a36b`, pushed; tree carries machine-maintained dirt only
  (whitelisted).
- Automation gate green since 08-29 09:01Z; five fix commits landed
  2026-08-30 (`be84690`, `760adb5`, `5b79b86`, `1113810`, `dcb6221`,
  swept as `1fd4808`).
- Evening plan `2026-08-28-evening-selfdev.plan.md` executed; no further
  accepted plan exists — machine is on research-beat filler until a new
  plan is accepted (R2).
- All 17+ timers active, 0 failed units (checked 2026-08-30T04:54Z).

Cross-links: [README.md](README-architecture.md) (suite index) ·
`hngh-automation/digest/TRIP-STATUS-2026-08-28.md` (stop-command source) ·
`hngh-automation/docs/NIGHT-OPS.md`.
