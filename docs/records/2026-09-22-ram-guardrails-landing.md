# 2026-09-22 — RAM guardrails + dashboard automation controls landing

Status: landed. Plan:
`docs/project/plans/2026-09-22-ram-guardrails-dashboard-controls.plan.md`
(v2, supportive + adversarial reviews integrated). Scope: automation/
(free-commit surface), dashboard UI, cadence/overnight gates,
docs/records. Kernel untouched.

## Context

Two Plasma session losses (2026-09-20 17:25, 2026-09-22 09:04) both from
`amdgpu: Not enough memory for command submission!` under user.slice RAM
exhaustion (brief:
`docs/agent-notes/briefs/2026-09-22-plasma-crash-gpu-memory-exhaustion.md`).
The dashboard sat dead after the crash with no auto-recovery, cadence
timers kept firing jobs into a low-memory machine, and the operator had
no remote way to pause/resume units. Bead hngh-bmb tracks the crash
signature.

## Landed slices (one commit each, pushed)

1. **Recovery widen** (`automation/cadence/day/11-service-recovery.sh`,
   commit 628ecc1b + test fix 5fac8158): refactored to
   `attempt(unit, port, stamp)`; recovers unsloth-studio:8888 AND
   hngh-dashboard.service:8890, one attempt per UTC day per unit
   (`~/.hngh-automation/.service-recovery-<unit>-<date>` stamps);
   operator-stop expected-state guard
   (`${HNGH_STOP_MARKER_DIR:-$HOME/.hngh-automation}/.operator-stop-<unit>`,
   touched by `service-ctl.sh stop`, removed by `start`) — recovery
   never undoes an operator stop. Tests: `automation/tests/test-service-ctl.py`
   36/36.

2. **RAM gate** (commit 4d47b9fd): `automation/lib/memory-gate.sh`
   `mem_ok` — floor = env `HNGH_MEM_FLOOR_MB` >
   cadence-params row `mem-available-floor-mb` (default 2048) >
   2048; parses MemAvailable, fail-closed (unreadable → 0). Sourced by
   `automation/jobs/cadence-tick.sh` (heavy tiers month|week|day|hour
   skip below floor with `progress` row `memory-gate:skip:<tier>`;
   rapid tiers 30m/10m/5m/1m unaffected) and by
   `automation/scripts/overnight-cycle.sh` per-spawn (reuses the STOP=1
   crash-net: skip = stop the night, not one spawn).

3. **Dashboard controls** (commit 7a9b4613): `service-ctl.sh`
   ALLOWLIST widened (8 cadence timers + hngh-automation.timer +
   night-agent/night-research/morning-report services +
   hngh-dashboard.service); timer stop = pause, start = resume, no
   operator-stop markers for timers. Dashboard route
   `system/service-act` (`automation/dashboard-server.py`):
   verbs start|stop|restart only, `UNIT_RE` sandbox, body parsed once,
   pre-writes `_handoff` audit row BEFORE exec (self-restart of the
   dashboard kills the server mid-response), execs
   `bash service-ctl.sh --json <unit> <verb>` (single gated path; the
   earlier `HNGH/scripts` path was wrong — rc=127 — fixed to
   `ROOT/scripts`). `system-view.js` unit input + start/stop/restart
   buttons with confirm. Token gate unchanged (LAN token; threat model
   in plan). Tests: test-service-ctl 36/36, test-dashboard-p1 27/27.
   Live smoke: timer stop/start round-trip + dashboard self-restart via
   the gated path.

4. **MemoryPeak** (commit 258ad00b): `probe_memory` in
   `automation/jobs/system-feed.py` now returns `used_gb` and
   `peak: {date, used_gb}` — running max used_gb since UTC midnight,
   state carried in `system-ops.json` itself (sole writer); Memory
   card shows `· peak N GB`. Live feed verified.

5. **Parked items** (report row alert `afd8588b`,
   `docs/project/reports.md`, body
   `docs/project/report-bodies/2026-09-22T14:57:08Z-alert-afd8588b.md`):
   (a) systemd resource caps on the hngh unit family (exact lines:
   `systemctl edit hngh-dashboard.service` → `[Service]
   MemoryHigh=400M` / `MemoryMax=1G`) — critical-class, operator-owned.
   SLA: revisit at next crash-class recurrence. Halt condition: RAM
   gate trips 3× in one day with desktop hogs resident.
   (b) chrome restart cadence + VRAM headroom (crash brief prevention
   item 1) — operator-side, same carrier. Neither is reported resolved
   without an operator disposition.

## Verification

Automation gate ALL PASS + lint clean (test-service-ctl 36/36,
test-dashboard-p1 27/27, test-system-feed 12/12,
test-memory-gate.sh green). Kernel gate green (2,934 checks).
Smoke tests live: service-ctl stop/start `hngh-cadence-month.timer`,
dashboard restart through the gated path, real feed run showing peak.

## Notes

- test-worker-render.sh closed-fd probe moved 9→109: node v26.9.0
  recycles freed LOW fd numbers into its own pipes/mmaps before user
  code runs, so `writeSync(9, …)` into a recycled fd can SIGBUS (rc=135);
  fd 109 stays genuinely closed. Production unaffected (launch-jcode.sh
  passes fd 3 explicitly open).
- Flake deferred: test_dashboard_down_starts_once_per_day failed twice
  under full-gate parallel load, 12/12 OK in clean-room isolation
  (12-iteration flake hunt, no repro). Watch for recurrence; suspect
  fresh-stamp timing race.
- Gate-sweep follow-up (commits 665b0a0b, 3ccbb620): the step-2 RAM
  gate broke four overnight-cycle sandbox tests
  (test-beat-blockers, test-overnight-forethought, test-overnight-
  shutdown, test-lifecycle-traps) plus test-plan-priority-selector —
  their fixed lib copy lists lacked memory-gate.sh, so in-sandbox
  sourcing failed and `memory_gate` command-not-found (rc 127) tripped
  STOP=1, silently stopping every sandbox batch. Red was pre-existing
  at the step-2 commit era (first full gate since then had stopped at
  the first FAIL). Fix: copy list carries memory-gate.sh + sandbox env
  HNGH_RAM_FLOOR_MB=1 (hermetic, not memory-dependent).
- Governance smell for the operator: the step-5 parked critical-class
  item (mem-caps-dropin:hngh-dashboard) was re-routed by
  scripts/router-tick.py as a normal-risk plan candidate
  (2026-09-22-routed-mem-caps-dropin-hngh-dashboard.plan.md). It cannot
  self-accept (its step needs passwordless sudo systemctl edit → fails
  closed), but a critical-class parked item surfacing as
  normal-risk-routable is a router policy gap, parked here for the
  operator's disposition.
