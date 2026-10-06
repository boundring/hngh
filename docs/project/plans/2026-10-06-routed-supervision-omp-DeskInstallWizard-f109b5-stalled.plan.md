<!-- plan: status=accepted risk=normal accepted=2026-10-06T15:07:10Z routed-from=supervision:omp-DeskInstallWizard-f109b5:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-13T15:00:42Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-06 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-DeskInstallWizard-f109b5:stalled`
at 2026-10-06T15:00:42Z. Alert text: agent-supervision: omp-DeskInstallWizard-f109b5 stalled (missed tick 1) — steer: hard error result, no corrective step: def _desk_run_aur(self):         """The gated user-session AUR build (docs block above): gates in         ORDER — body shape, AUR_PKGS membership, phase-1 appro cause=repeat-loop expires=2026-10-13T14:24:14Z

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
