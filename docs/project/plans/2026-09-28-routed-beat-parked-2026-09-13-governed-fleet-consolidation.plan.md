<!-- plan: status=accepted risk=normal accepted=2026-09-29T14:05:41Z routed-from=beat-parked:2026-09-13-governed-fleet-consolidation -->
<!-- attempt: 2 -->
<!-- expires: 2026-10-05T23:00:53Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-09-28 — routed candidate

Routed by scripts/router-tick.py from alert identity `beat-parked:2026-09-13-governed-fleet-consolidation`
at 2026-09-28T23:00:53Z. Alert text: orchestrator blocker parked '2026-09-13-governed-fleet-consolidation': 2 consecutive deaths with cause class 'bad-execution' (blocker-escalate-n reached). Fix or remove the state/beat-blockers.tsv row to re-admit. ×2

## Steps

- [ ] Delve: open research subject fail-20260928-beat-parked-2026-09-13-governed-fleet-consolidation for beat-parked:2026-09-13-governed-fleet-consolidation; record disposition; then fix or park
      Verification: research subject fail-20260928-beat-parked-2026-09-13-governed-fleet-consolidation present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Occurrences

- 2026-09-30T00:00:48Z re-occurred (dedup window expired)
