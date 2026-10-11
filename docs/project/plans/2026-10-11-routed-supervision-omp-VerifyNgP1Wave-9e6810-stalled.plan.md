<!-- plan: status=proposed risk=normal accepted=- routed-from=supervision:omp-VerifyNgP1Wave-9e6810:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-18T18:00:13Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-11 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-VerifyNgP1Wave-9e6810:stalled`
at 2026-10-11T18:00:13Z. Alert text: agent-supervision: omp-VerifyNgP1Wave-9e6810 stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-18T17:45:22Z ×3

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
