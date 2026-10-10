<!-- plan: status=executed risk=normal accepted=2026-10-02T20:35:17Z routed-from=expired:patrol:handoffs -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-09T18:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-02 — routed candidate

Routed by scripts/router-tick.py from alert identity `expired:patrol:handoffs`
at 2026-10-02T18:00:41Z. Alert text: identity expired: patrol:handoffs cannot close within its window (expires=2026-10-02T16:35:36Z); auto-parked after one operator escalation -- close the condition or re-arm by clearing its identity state

## Steps

- [x] Delve: open research subject fail-20261002-expired-patrol-handoffs for expired:patrol:handoffs; record disposition; then fix or park
      Verification: research subject fail-20261002-expired-patrol-handoffs present in research-subjects.txt with a recorded disposition; alert fixed or parked
