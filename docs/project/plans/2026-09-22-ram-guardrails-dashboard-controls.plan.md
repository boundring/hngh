<!-- plan: status=accepted risk=normal accepted=2026-09-22T16:03:32Z -->

Slug: 2026-09-22-ram-guardrails-dashboard-controls (repo plan
docs/project/plans/2026-09-22-ram-guardrails-dashboard-controls.plan.md,
status=proposed). v2: both reviews integrated (supportive: all steps hold,
1 blocking gap; adversarial: 7 breaks, amendments applied). Grants: the
2026-09-22 operator directive extends service-management.md first, script
second (docs/design/service-management.md:103-105 doc-first rule).

## Review deltas integrated

- B1: recovery no-ops without service-ctl.sh ALLOWLIST widening
  (hngh-dashboard.service added; doc-first extension recorded). BLOCKING, fixed in step 1.
- B6: per-unit recovery stamps (.service-recovery-<UNIT>-<UTC-date>).
- B4: recovery never undoes operator stops (expected-state check on a
  recent operator-stop audit row / marker file, breadcrumb carries staleness).
- B2/B2b: shared lib automation/lib/memory-gate.sh sourced by cadence-tick
  (skip month|week|day|hour; run 30m/10m/5m/1m) AND overnight-cycle.sh
  per-spawn check reusing the STOP=1 crash-net path; explicit belt-only
  scoping (root cause was chrome/games, not hngh); MemAvailable swap
  blind-spot noted in a comment; PSI is the upgrade path, skipped now.
- B3: dashboard actions = start|stop|restart ONLY (enable/disable stay
  critical-class and cannot pause timers anyway); unit allowlist includes
  hngh-cadence-*.timer forms (timer stop = real pause).
- B5: endpoint execs scripts/service-ctl.sh (the single gated path); no
  raw systemctl in dashboard-server.py; _handoff audit row pre-written
  before self-affecting restart/stop.
- B7: step 4 reduces to MemoryPeak (MemAvailable already feeds
  system-ops.json via probe_memory system-feed.py:144-156).
- Conditions adopted: UNIT_RE + list-argv sandbox copied from
  _system_reset_failed (dashboard-server.py:858-875); token threat model
  stated; night-agent/night-research/morning-report ADDED to the unit
  allowlist (runaway-kill is the point); endpoint count = 12 (not 11);
  smoke = hngh-cadence-month.timer start/stop; step 5 parked items carry
  SLA + halt conditions; test-service-ctl.py:350-355 asserts the literal
  unsloth UNIT — kept, dashboard branch is additive.

## Steps

- [ ] 1. RECOVERY-WIDEN — (a) docs first: add hngh-dashboard.service:8890
      to docs/design/service-management.md section 2 allowlist table (grant:
      operator directive 2026-09-22). (b) add hngh-dashboard.service to
      automation/scripts/service-ctl.sh ALLOWLIST (:35) + usage docstring.
      (c) widen automation/cadence/day/11-service-recovery.sh into a
      unit:port loop: [unsloth-studio.service:8888,
      hngh-dashboard.service:8890]; PER-UNIT stamps
      .service-recovery-<UNIT>-<UTC-date> (B6); before starting, check for a
      recent operator-stop audit row or expected-state marker (B4) — found =
      breadcrumb-and-exit (staleness noted); start via service-ctl.sh, wait,
      re-probe, one attempt per UTC day per unit, never restart an active
      unit; alert row on persistent failure. Keep the literal unsloth UNIT
      assertions in tests/test-service-ctl.py ServiceRecovery intact and add
      dashboard cases copying its env-seam pattern (:297-416, SHOW_STUB,
      RQ_STUB, real bound listener, per-unit stamp seam).
      Verification: automation `make test` green incl. new dashboard
      recovery cases (down+start-once+no-undo-after-operator-stop);
      kernel `make test` green.
      SLA: one slice, one commit, gates green same session.
      Halt: if recovery requires enabling/creating a unit, park (critical-class).
- [ ] 2. RAM GATE — new automation/lib/memory-gate.sh (~15 lines): floor =
      env HNGH_MEM_FLOOR_MB > cadence-params row mem-available-floor-mb
      (2048 default; operator owns value); parse MemAvailable from
      "${HNGH_MEMINFO_FILE:-/proc/meminfo}" (reuse the deck-producer.sh
      f_meminfo awk shape; fail-closed skip on unreadable file); comment
      notes the swap blind spot (MemAvailable ignores swap pressure) and
      belt-only scoping: the 2026-09-22 crash root cause was chrome/games
      VRAM+GTT exhaustion — this gate stops hngh adding the last straw, it
      is not a resource controller. Consumers: (a) jobs/cadence-tick.sh
      sources it after TIER validation (:17-23) — trip = skip
      month|week|day|hour with one breadcrumb row (expected-state, NO
      alert), 30m/10m/5m/1m heartbeats/feeds always run; (b)
      scripts/overnight-cycle.sh sources it at the per-spawn site beside
      failfirst_gate (:781-790) — trip = breadcrumb `mem-floor` and take
      the existing STOP=1 crash-net path (:56-70, stop spawning, leave
      in-flight slugs, exit cleanly).
      Verification: automation `make test` green incl. bash tests with
      HNGH_MEMINFO_FILE stubs (below floor skips day tier + breadcrumb;
      normal runs it; overnight per-spawn trip exercises the STOP=1 path);
      kernel `make test` green.
      SLA: one slice, one commit.
      Halt: if gating needs cgroup/systemd state, park (step 5 territory).
- [ ] 3. DASHBOARD CONTROLS — token-gated POST /system/unit-action
      {"unit": str, "action": str} as the 13th route in the do_POST
      dispatch dict (dashboard-server.py:793-804), copying the
      _system_reset_failed sandbox (:858-875): IP allowlist -> _token_ok
      -> 64KB body cap -> UNIT_RE fullmatch -> EXACT-match unit allowlist
      -> subprocess list-argv (no shell), timeout 15.
      Unit allowlist (exact strings): hngh-{cadence-1m,5m,10m,30m,hour,
      day,week,month,automation,overnight,autonomy,dashboard}.service,
      hngh-{cadence-1m,5m,10m,30m,hour,day,week,month}.timer,
      hngh-{night-agent,night-research,morning-report}.service.
      Actions: start|stop|restart ONLY (enable/disable stay critical-class
      and cannot pause timers; timer stop IS the pause). Execution route:
      `bash scripts/service-ctl.sh <unit> <verb>` (the single gated path —
      B5); service-ctl.sh gains nothing beyond the B1 allowlist entry.
      Audit: _handoff row pre-written BEFORE exec when the action targets
      hngh-dashboard.service itself (self-restart loses post-exec rows);
      service-ctl breadcrumbs + report rows cover everything else.
      UI: dashboard/system-view.js toggles per unit/action via its post()
      helper (:53-56; reset-failed handler :314-323 is the template); app.js
      :48-82 carries the X-Hngh-Token plumbing.
      Threat model (stated): the POST token guards LAN-mutating actions,
      not secrets; a tailnet phone with mailbox access holds the token;
      machine sessions are barred from the endpoint by the autonomy rule,
      which is convention + gate, not technical enforcement — acceptable
      on a single-operator box.
      Verification: automation `make test` green with in-process server
      tests (test-dashboard-p1.py ServerTest pattern :89-141: module-var
      seams, post() helper; assert token gate, non-allowlisted unit ->
      404, unknown action -> 400, valid case asserts the exact
      service-ctl.sh argv via a stub PATH bin); kernel `make test` green;
      live smoke: stop+start hngh-cadence-month.timer via curl with the
      dashboard token, observe the unit state flip.
      SLA: one slice, both gates green.
      Halt: operator asks for per-action re-login auth -> park extension.
- [ ] 4. MEMORY VISIBILITY — add per-unit MemoryPeak to system-feed.py:
      one batched `systemctl --user show -p MemoryPeak <units>` probe fn
      following the probe_* registry (:293-297) + probe_units parser shape
      (:91-119), fail-closed (None, reason) like siblings; extend the
      existing probe_memory dict rather than a parallel probe (MemAvailable
      already feeds system-ops.json at :294); render the columns in
      dashboard/system-view.js next to the step-3 toggles. Add the meminfo
      path param to probe_memory (:148 hardcoded open) only if the test
      needs it.
      Verification: automation `make test` green (tests/test-system-feed.py
      importlib + tmp fixtures pattern :20-62; fail-closed omitted-note
      assert); kernel `make test` green; live: System page renders columns.
      SLA: same-session slice.
      Halt: per-unit peaks need privileges -> reduce to MemAvailable only.
- [ ] 5. PARKED (operator-owned, escalation-SLA carrying): (a) systemd
      resource caps on the hngh unit family — MemoryHigh/MemoryMax drop-ins
      are unit-file edits = critical-class; file ONE operator item via
      automation/lib/operator-item.sh naming exact lines
      (hngh-dashboard.service: MemoryHigh=400M, MemoryMax=1G; cadence
      services short-lived, cadence-1m peak 75MB — no caps proposed).
      SLA: revisited at the next recurrence of the crash class
      (docs/agent-notes/briefs/2026-09-22-plasma-crash-gpu-memory-exhaustion.md).
      Halt condition: the step-2 RAM gate tripping N=3 times in one day
      with the desktop hogs resident pages the operator instead of
      silently skipping. (b) chrome restart cadence + VRAM headroom
      (crash brief prevention item 1) — operator-side, same SLA/halt
      carrier. Neither parked item is ever reported resolved without an
      operator disposition.
      Verification: operator-item row exists naming the exact drop-in
      lines; no code change; kernel `make test` green.

## Notes

- Dashboard controls touch already-installed units only, operator-clicked,
  token-gated, every action lands an audit row (service-ctl breadcrumbs +
  report rows; pre-written _handoff for self-affecting actions).
- The memory-pressure gate is expected-state routing (skip + breadcrumb),
  never an alert class.
- Operational recovery already executed live 2026-09-22 (disclosed):
  hngh-dashboard.service started + enabled (pre-crash state; HTTP 200).
  That one-time enable is the operator's own console action on record;
  the B3 amendment keeps enable/disable out of the machine/dashboards'
  routine surface.
- Line refs verified this session by both reviews: do_POST :781, token
  guard :760-779 + scheme :301-318, dispatch dict :793-804 (12 routes),
  _system_reset_failed :858-875, service-ctl ALLOWLIST :35 + verb grant
  :65-70, recovery seams :38-42, tick flock :26-31, overnight per-spawn
  gates :781-790 + STOP=1 :56-70, probe_memory :144-156, probe registry
  :293-297, service-management.md doc-first :103-105 + critical-class
  :87-89.
