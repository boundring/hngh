<!-- plan: status=accepted risk=normal accepted=2026-10-14T00:05:44Z routed-from=supervision:omp-mnemopi-triage-90ffd3:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-19T15:00:12Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-12 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-mnemopi-triage-90ffd3:stalled`
at 2026-10-12T15:00:12Z. Alert text: agent-supervision: omp-mnemopi-triage-90ffd3 stalled (missed tick 1) — steer: hard error result, no corrective step: Oct 12 01:13:07 brickertop kernel: usb 1-4: device descriptor read/64, error -71 Oct 12 01:13:08 brickertop kernel: usb 1-4: device not accepting address 14, er cause=repeat-loop expires=2026-10-19T13:11:47Z ×18

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
