<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z routed-from=push-divergence-jcode-20260914 -->
# 2026-09-14 — routed candidate

Routed by scripts/router-tick.py from alert identity `push-divergence-jcode-20260914`
at 2026-09-14T19:00:13Z. Alert text: git push non-fast-forward (2nd): local main grew to jcode-witness slice commits b171769 + agent-supervision path fix on top of unreconciled 660ba14/54679ba; origin main still rewritten at 821c422 — reconciler task unchanged

## Steps

- [x] Delve: open research subject fail-20260914-push-divergence-jcode-20260914 for push-divergence-jcode-20260914; record disposition; then fix or park
      Verification: research subject fail-20260914-push-divergence-jcode-20260914 present in research-subjects.txt with a recorded disposition; alert fixed or parked
      **Closed 2026-09-14T20:08Z:** subject row landed. Root cause
      (FIXED): two same-host jcode sessions raced origin main — the
      coordinator session force-pushed 821c422 (a stale duplicate of
      the local d8fd49a lineage) while this lane held the linear
      superset; resolved same hour via force-with-lease to the
      superset (behind=0, ahead=0). Preventive rule recorded in
      docs/records/2026-09-14-jcode-shared-sense.md: one writer per
      file per slice; coordinate before force operations on shared
      refs.

## Occurrences

- 2026-09-14T20:00:33Z re-occurred (dedup window expired)
- 2026-09-14T21:00:13Z re-occurred (dedup window expired)
