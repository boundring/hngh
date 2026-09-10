<!-- plan: status=parked risk=normal accepted=2026-09-06T01:01:30Z routed-from=system-network-down  cause=duplicate disposed=2026-09-09T15:27:53Z reason="same identity (×11 counter), keep 2026-09-06-routed-system-network-down"-->
# 2026-09-05 — routed candidate

Routed by scripts/router-tick.py from alert identity `system-network-down`
at 2026-09-05T01:00:45Z. Alert text: [oversight] system-network-down: critical resource flag set ×11

## Steps

- [ ] Investigate the alert, fix or park, with a named verification
      Verification: `make test` green in the owning repo

## Occurrences

- 2026-09-10T00:00:18Z re-occurred (dedup window expired)
- 2026-09-10T02:00:18Z re-occurred (dedup window expired)
