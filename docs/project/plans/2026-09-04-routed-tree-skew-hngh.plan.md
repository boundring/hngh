<!-- plan: status=parked risk=normal accepted=2026-09-04T00:01:24Z routed-from=tree-skew:hngh  cause=duplicate disposed=2026-09-09T15:27:53Z reason="same identity, keep newest carrier 2026-09-06-routed-tree-skew-hngh-2"-->
# 2026-09-04 — routed candidate

Routed by scripts/router-tick.py from alert identity `tree-skew:hngh`
at 2026-09-04T00:00:45Z. Alert text: [oversight] tree-skew: Projects/etc/hngh dirty and uncommitted >4h ×63

## Steps

- [ ] Whitelist check + handoff/commit of the stalled edit
      Verification: dirty-tree whitelist clean; stalled edit committed or handed off
