<!-- plan: status=proposed risk=normal accepted=- -->
# RAM guardrails + dashboard automation controls (post-OOM-crash hardening)

Proposed via `omp-bridge --propose` (omp session propose surface;
see docs/project/plans/README.md).

Operator directive 2026-09-22 after the amdgpu-BO-exhaustion session crash
(diagnosis: docs/agent-notes/briefs/2026-09-22-plasma-crash-gpu-memory-exhaustion.md):
manage RAM use carefully so hngh automation never clobbers the system, and
give the dashboard toggles/controls for hngh automation. Grounded gaps:
(a) the dashboard itself (hngh-dashboard.service, MemoryPeak 1.6G observed)
died in the crash reboot and stayed down until manually restarted —
cadence/day/11-service-recovery.sh guards ONLY unsloth-studio:8888;
(b) no memory-pressure gate exists in the cadence ticks (only
research-load-ceiling on loadavg); (c) the dashboard has 11 token-gated
POST endpoints (incl. /system/reset-failed {"unit"}) but no unit
start/stop/enable controls; (d) unit-file resource caps
(MemoryHigh/MemoryMax) are operator-owned (unit-file edits are
critical-class per docs/design/service-management.md).

Operational recovery already executed live 2026-09-22 (disclosed):
hngh-dashboard.service started + enabled (pre-crash state restored;
HTTP 200). The operator may revert the enable per the critical-class rule.

## Steps

- [ ] 1. RECOVERY-WIDEN — extend
      automation/cadence/day/11-service-recovery.sh (or a sibling drop-in)
      to also guard hngh-dashboard.service on http://127.0.0.1:8890: if
      down AND unit installed-but-inactive -> scripts/service-ctl.sh
      hngh-dashboard.service start (sanctioned recovery path), wait, re-probe,
      one attempt per UTC day, never restart an active unit; alert row naming
      unit state on persistent failure. Follow the unsloth branch's exact
      shape (per-day state file, progress/alert rows, no unit-file edits).
      Verification: automation `make test` green with a hermetic test
      stubbing the HTTP probe + systemctl seam (env HNGH_SERVICE_PROBE_PORT /
      PATROL_SYSTEMCTL-style seams already exist in the beat family);
      kernel `make test` green.
      SLA: one slice, one commit, gates green same session.
      Halt: if recovery requires enabling/creating a unit (unit-file edit),
      park — critical-class, operator only.
- [ ] 2. RAM GATE — cadence beats skip heavy work under memory pressure:
      new cadence-params row `mem-available-floor-mb` (2048 default; env
      HNGH_MEM_FLOOR_MB overrides; operator owns the value) checked at
      cadence-tick start (jobs/cadence-tick.sh, or the shared lib) from
      /proc/meminfo MemAvailable; below floor -> skip heavy tiers
      (overnight, unsloth-contexts, manga vision/imagegen, research model
      legs) with a breadcrumb row (expected-state, like deck off-duty —
      NO alert spam), run the lightweight tiers (1m/5m heartbeats, feeds).
      Verification: automation `make test` green incl. a test that a
      sandboxed /proc substitute (env seam for the meminfo path) below the
      floor skips the heavy tier and logs the breadcrumb, and a normal-
      memory case runs it; kernel `make test` green.
      SLA: one slice, one commit.
      Halt: if gating needs unit-level cgroup state (systemd drop-ins),
      park — that is step 5 territory.
- [ ] 3. DASHBOARD CONTROLS — token-gated POST /system/unit-action
      {"unit": str, "action": str} following the existing 11-endpoint
      pattern (automation/dashboard-server.py:781 do_POST + shared guard
      :761): allowlist units = hngh-{cadence-1m,5m,10m,30m,hour,day,week,
      month,automation,overnight,autonomy,dashboard}.service + actions =
      start|stop|restart|enable|disable; anything else -> 404 fail-closed;
      action executes via systemctl --user on the already-installed unit
      (never unit-file edits); result row + UI toggles on the System page
      (automation/dashboard/ system view + app.js POST helper per the
      /system/reset-failed pattern). Machine sessions NEVER call this
      endpoint — it exists for the operator's browser (token-gated).
      Verification: automation `make test` green incl. hermetic endpoint
      tests (stub systemctl via env seam; assert allowlist refuses
      non-hngh units and unknown actions with 404/400, token gate enforced,
      valid start/stop passes through); kernel `make test` green; live
      smoke: toggle hngh-cadence-month.timer (harmless) start/stop via
      curl with the dashboard token and observe the unit state flip.
      SLA: one slice, both gates green.
      Halt: if the endpoint needs auth beyond the existing POST token
      (operator asks for re-login per action), park that extension.
- [ ] 4. MEMORY VISIBILITY — system feed gains RAM columns:
      automation/jobs/system-feed.py adds MemAvailable + MemoryPeak for the
      hngh unit family (systemctl show -p MemoryPeak, one call batch) to the
      System page so the operator sees the automation footprint next to the
      toggles. Small read-only slice.
      Verification: automation `make test` green (feed schema test updated);
      live: dashboard System page renders the new columns.
      SLA: same-session slice.
      Halt: if per-unit peaks require privileged access, reduce scope to
      MemAvailable only.
- [ ] 5. PARKED (operator-owned): systemd resource caps on the hngh unit
      family (MemoryHigh/MemoryMax drop-ins, e.g. dashboard MemoryHigh=400M
      Max=1G observed peak; cadence services are short-lived and already
      small — cadence-1m peak 75MB). Unit-file edits are critical-class;
      file one operator item naming the exact drop-in lines and let the
      operator apply or delegate. Also operator-side: chrome restart
      cadence + VRAM headroom (crash prevention item 1, already recorded
      in the plasma-crash brief).
      Verification: operator item row exists naming exact values; no code
      change.
      SLA: item filed the same session.
      Halt: operator declines -> item closed with disposition.

## Notes

- Dashboard controls touch systemd unit state of already-installed units
  only; enable/disable are in the allowlist because the operator just saw
  the cost of a unit staying down — every toggle is operator-clicked
  (token-gated) and logged as a report row.
- The memory-pressure gate is expected-state routing (skip + breadcrumb),
  never an alert class, so it cannot spam the queue under pressure.
