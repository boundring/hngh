<!-- plan: status=parked risk=normal accepted=2026-09-04T02:01:26Z routed-from=system-network-down  cause=duplicate disposed=2026-09-09T15:27:53Z reason="same identity system-network-down, 3 accepted re-routes; newest carrier 2026-09-06 stays live (premise intermittent: last firing 2026-09-08T07:20Z, STATE.md)"-->
# 2026-09-04 — routed candidate

Routed by scripts/router-tick.py from alert identity `system-network-down`
at 2026-09-04T01:00:45Z. Alert text: [oversight] system-network-down: critical resource flag set

## Steps

- [ ] Investigate the alert, fix or park, with a named verification
      Verification: `make test` green in the owning repo
