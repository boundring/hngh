<!-- plan: status=expired risk=normal accepted=- routed-from=beat-parked:2026-09-13-governed-fleet-consolidation -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-04T23:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-09-27 — routed candidate

Routed by scripts/router-tick.py from alert identity `beat-parked:2026-09-13-governed-fleet-consolidation`
at 2026-09-27T23:00:41Z. Alert text: orchestrator blocker parked '2026-09-13-governed-fleet-consolidation': 2 consecutive deaths with cause class 'bad-execution' (blocker-escalate-n reached). Fix or remove the state/beat-blockers.tsv row to re-admit.

## Steps

- [ ] Delve: open research subject fail-20260927-beat-parked-2026-09-13-governed-fleet-consolidation for beat-parked:2026-09-13-governed-fleet-consolidation; record disposition; then fix or park
      Verification: research subject fail-20260927-beat-parked-2026-09-13-governed-fleet-consolidation present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Occurrences

- 2026-09-28T23:00:53Z re-occurred (dedup window expired)
