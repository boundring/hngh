# 2026-09-22 — RAM gate trip telemetry (OOM-prevention handoff P3)

Evidence base: docs/agent-notes/briefs/2026-09-22-oom-prevention-handoff.md
(crash class: amdgpu command-submission exhaustion, kernel OOM-killer never
fired). The RAM belt gate `automation/lib/memory-gate.sh` tripped silently —
refusals were invisible unless a breadcrumb was grepped by hand.

## Change

`memory_gate` on a below-floor trip now calls `alert_row "ram-gate:trip"
86400 ...` (notify-email seam): one report-queue alert row per trip day,
deduped by identity+window, re-firing after 24h if the pressure persists,
expiring 24h after the last trip. Row text states SLA + halt.

## SLA + halt (escalation-sla rule)

- SLA: re-fires per trip day, expires 24h after the last trip.
- Halt: none — pure telemetry, no retry loop behind the gate; the
  overnight/cadence halt itself is STOP=1.
- Routed != resolved: this row is early-warning telemetry only; the OOM
  queue closes only when systemd-oomd (P1, operator sudo) is live and a
  clean day passes.

## Verification

`automation/tests/test-memory-gate.sh` case 6: trip files exactly one
`--identity ram-gate:trip --window 86400` row with SLA/halt text (hermetic
fake report-queue logging argv); a healthy pass files none. Full automation
gate green at landing.
