<!-- plan: status=proposed risk=normal accepted=- routed-from=mem-caps-dropin:hngh-dashboard -->
# 2026-09-22 — routed candidate

Routed by scripts/router-tick.py from alert identity `mem-caps-dropin:hngh-dashboard`
at 2026-09-22T15:01:03Z. Alert text: [PARKED plan step 5a] systemd resource caps = critical-class, needs your disposition. Exact lines: sudo systemctl edit hngh-dashboard.service -> [Service] MemoryHigh=400M / MemoryMax=1G (dashboard processes peaked ~490MB during 2026-09-22 crash-window). Chrome restart cadence + VRAM headroom = same parked carrier (crash brief prevention item 1). SLA: revisit at next crash-class recurrence (docs/agent-notes/briefs/2026-09-22-plasma-crash-gpu-memory-exhaustion.md). Halt condition: RAM gate (mem-available-floor-mb) trips 3x in one day with hogs resident.

## Steps

- [ ] Delve: open research subject fail-20260922-mem-caps-dropin-hngh-dashboard for mem-caps-dropin:hngh-dashboard; record disposition; then fix or park
      Verification: research subject fail-20260922-mem-caps-dropin-hngh-dashboard present in research-subjects.txt with a recorded disposition; alert fixed or parked
