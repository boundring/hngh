#!/usr/bin/env bash
# memory-gate — belt-only RAM floor for spawn-heavy surfaces
# (plan 2026-09-22-ram-guardrails-dashboard-controls step 2).
#
# The Plasma crashes (2026-09-22 root-cause brief) were amdgpu command-
# submission exhaustion under a full RAM+swap machine; the OOM-killer
# never fired. A belt gate that refuses to SPAWN new heavy work while
# MemAvailable is below the floor is the cheap, targeted defense — not a
# cgroup hierarchy, not a general memory manager.
#
# Floor precedence: env HNGH_RAM_FLOOR_MB > cadence-params row
# ram-gate-floor-mb > 2048 (MB). Callers must have sourced common.sh
# (AUTOMATION_ROOT, breadcrumb env) first; this sources params.sh,
# breadcrumbs.sh, and notify-email.sh.
#
# A below-floor trip files one deduped report-queue alert row (identity
# ram-gate:trip, window 86400 — re-fires per trip day) so trips become
# visible telemetry (oom-prevention handoff P3); the row never fails the
# gate and the email channel stays dormant unless configured.
#
# usage: . "$AUTOMATION_ROOT/lib/memory-gate.sh"
#        memory_gate || <skip heavy work>
set -u

. "${AUTOMATION_ROOT:?memory-gate needs AUTOMATION_ROOT (source common.sh first)}"/lib/params.sh
. "${AUTOMATION_ROOT:?memory-gate needs AUTOMATION_ROOT (source common.sh first)}"/lib/breadcrumbs.sh
. "${AUTOMATION_ROOT:?memory-gate needs AUTOMATION_ROOT (source common.sh first)}"/lib/notify-email.sh

mem_available_mb() { # -> MemAvailable in whole MB on stdout
 awk '/^MemAvailable:/ {printf "%d", $2/1024; exit}' /proc/meminfo
}

memory_gate() { # -> rc 0 continue (healthy) / rc 1 below floor (skip)
 local floor="${HNGH_RAM_FLOOR_MB:-$(get_param ram-gate-floor-mb 2048)}"
 local avail
 avail="$(mem_available_mb)"
 if [ -z "$avail" ]; then
  # unreadable /proc/meminfo: fail open — the gate is a belt, not the
  # system of record, and a bogus probe must not stall every tick
  return 0
 fi
 if [ "$avail" -ge "$floor" ]; then
  return 0
 fi
 breadcrumb "${JOB_NAME:-memory-gate}" "memory-gate" \
  "MemAvailable=${avail}MB < floor=${floor}MB — heavy work skipped"
 alert_row "ram-gate:trip" 86400 \
  "[hngh] RAM gate tripped: MemAvailable=${avail}MB < floor=${floor}MB" \
  "MemAvailable=${avail}MB < floor=${floor}MB (${JOB_NAME:-memory-gate} skipped heavy work). SLA: re-fires per trip day, expires 24h after the last trip. Halt: none — pure telemetry, no retry loop behind the gate (the cadence/overnight halt itself is STOP=1)."
 return 1
}
