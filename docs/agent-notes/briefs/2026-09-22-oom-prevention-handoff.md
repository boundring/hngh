# Handoff: OOM / Plasma-crash prevention queue (next session)

Written 2026-09-22 end-of-session by the federal-branches session. This is the
OOM follow-up work queue the operator asked to carry forward. If you are the
next session: this queue is your second task after orientation (first = any
live red gate / alert the operator names).

## Crash-class facts (evidence base)
- Two Plasma session losses, root cause `amdgpu: Not enough memory for command submission!`
  (kernel BO exhaustion) under user.slice ~27G/30G RAM + 15.2G swap; Mesa radeonsi
  SIGABRT killed Xorg within ~1s; plasmalogin greeter died with no retry/fallback.
  NOT OOM-killer, NOT hngh (Linger kept units alive).
- Hogs at crash: chrome 2.9G RSS + 1.7G swap, firefox, steam, tauonmb, unsloth-studio (:8888).
- Brief: `docs/agent-notes/briefs/2026-09-22-plasma-crash-gpu-memory-exhaustion.md` (commit 29beb928).
  Bead `hngh-bmb` = patrol signature. Parked alert `afd8588b` = mem-caps item A
  (done, 0c42b56c) + item 5b chrome cadence/VRAM headroom (open).
- Landed guards: RAM gate `automation/lib/memory-gate.sh` (floor env
  HNGH_RAM_FLOOR_MB > cadence-params row ram-gate-floor-mb > 2048 MB),
  MemoryPeak in system-feed, dashboard mem-caps (user unit drop-in, MemoryHigh=400M/MemoryMax=1G).
- KEY GAP: nothing on the box kills hogs under memory pressure — the GPU driver
  aborts before the OOM-killer fires, so the session dies with no rescue.

## Work queue (priority order)

### P1 — systemd-oomd (NEEDS OPERATOR SUDO; hand the exact commands)
```bash
sudo systemctl enable --now systemd-oomd.service
sudo mkdir -p /etc/systemd/system/user@.service.d
sudo tee /etc/systemd/system/user@.service.d/oomd.conf <<'EOF'
[Service]
ManagedOOMMemoryPressure=kill
ManagedOOMMemoryPressureLimit=60%
EOF
sudo systemctl daemon-reload
```
Kills the worst cgroup at 60% PSI sustained ~1min. Fallback: earlyoom if oomd too
passive. Likely prevents both past crashes alone.

### P2 — cap unsloth-studio (user unit, NO sudo, machine-lane OK)
1. Measure first: `systemd-cgtop -1`, `journalctl -u unsloth-studio` over a normal day.
2. Then `~/.config/systemd/user/unsloth-studio.service.d/mem-caps.conf` ->
   `[Service] MemoryMax=<measured+headroom>G`; `systemctl --user daemon-reload && systemctl --user restart unsloth-studio`.
3. VRAM half of item 5b: if vLLM/llama.cpp server, cap `gpu-memory-utilization` /
   `--n-gpu-layers` to leave desktop headroom (7900 XTX).
- Caution: unsloth is the Jev seam (http://127.0.0.1:8888) — a MemoryMax kill takes
  cadence's Jev triage down with it (cheap fail, jev-error re-ask hourly); pick the cap generously.

### P3 — RAM gate -> operator surface (automation lane, small, DO THIS SESSION)
- `automation/lib/memory-gate.sh` trips silently today. Wire a report-queue alert on
  trip: identity `ram-gate:trip`, window 86400, so trips become visible telemetry.
  Row text must state SLA + halt (escalation-sla rule): SLA = signal re-fires per trip
  day and expires 24h after the last trip; halt = none needed (pure telemetry, no retry
  loop behind it — the overnight/cadence halt itself is STOP=1).
- Bead `hngh-bmb` carries the crash-class patrol signature.
- LANDED 2026-09-22 (later session): alert wired via notify-email's alert_row, test
  case 6 in test-memory-gate.sh, full automation gate green. Record:
  docs/records/2026-09-22-oom-p3-ram-gate-alert.md. P2 also landed: unsloth-studio
  user-unit drop-in mem-caps.conf (MemoryHigh=16G/MemoryMax=20G, unit MemoryPeak
  observed 15.5GiB); VRAM half of 5b still open.

### P4 — Chrome hygiene (parked 5b, operator habit)
- chrome://discards tab discard works; or periodic chrome restart cadence. Only if
  crashes recur after P1-P2.

### P5 — recurrence evidence (ONLY if crash recurs)
- `journalctl -b -1 -k | grep -i amdgpu`; with oomd live, `journalctl | grep oomd`
  names the killed cgroup directly — turns recurrence into one-line diagnosis.

## Skipped (deliberate, revisit only if P1+P2 insufficient)
zram/swap tuning, `amdgpu.gttsize` kernel param, atop accounting — complex knobs, side effects.

## SLA + halt for this queue (escalation-sla rule)
- SLA: actionable at the next repo-touching session — P3 is machine-lane and lands
  that session; P1/P2 are operator-gated, and their deadline signal is a third
  crash-class recurrence bumping parked alert `afd8588b` (same row, never silent).
- Halt: lane ends after P1+P2 land and one clean day passes — nothing more queues.
  If crashes recur AFTER oomd is live, one escalation to the kernel-parameter lane
  (P5 evidence gathered first), then stop.
- Routed != resolved: P3's `ram-gate:trip` alert is early-warning telemetry only; no
  item is "fixed" until verified against a real recurrence window or operator-closed.

## Session-end state at writing time (2026-09-22, for context)
- Plan `docs/project/plans/2026-09-22-federal-branches-occupancy.plan.md` COMPLETE
  (12/12): bailiff `3872b907`, executive guard `6ec4d02f`, bead intake `560db00e`,
  SLA template `ef0223c0` (was == origin/main HEAD at writing).
- Both gates green at writing: kernel rc=0 (2,934 checks), automation rc=0 (83 suites + lint).
- Deliberately uncommitted machine churn: `automation/research-subjects.txt`,
  `docs/design/ui-evolve/current-overlay.json`, `docs/project/ui-grades.md`,
  timer-owned routed plan files.
- Live operator surface: 11 escalation alerts (17:03:15Z, one per open bead,
  jev-escalate) — ROUTED NOT RESOLVED. Lane SLA: 7-day bump window then expire on
  silence. Halt: per-bead attempt cap -> attempts-exhausted -> bead leaves the loop
  (STATE.exhausted in automation/ng/cadence.py).
