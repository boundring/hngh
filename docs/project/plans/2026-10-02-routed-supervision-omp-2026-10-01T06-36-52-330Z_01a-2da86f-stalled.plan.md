<!-- plan: status=proposed risk=normal accepted=- routed-from=supervision:omp-2026-10-01T06-36-52-330Z_01a-2da86f:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-09T09:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-02 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-2026-10-01T06-36-52-330Z_01a-2da86f:stalled`
at 2026-10-02T09:00:41Z. Alert text: agent-supervision: omp-2026-10-01T06-36-52-330Z_01a-2da86f stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-08T07:17:22Z ×33

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
