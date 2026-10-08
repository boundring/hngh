# killed before research: fail-20260916-overnight-plan-accept-gate-automation

Status: closed 2026-10-08 (overnight-lead session). Alert identity
`overnight:plan-accept-gate:automation` — plan acceptance blocked:
hngh-automation make test FAILED (rc=2) ×3, routed 2026-09-16T19:00:34Z.

## Verdict

Killed — resolved before research. The 2026-09-15/16 rc=2 window self-healed
with zero automation commits and never reproduced with captured output.

## Evidence

1. **Self-heal window.** No automation commits landed 2026-09-15 through
   2026-09-18 evening, yet plan acceptance succeeded 2026-09-18T01:41:57Z —
   acceptance requires both gates green, so the red cleared without a code
   change. Transient class, matching the sibling kernel precedent
   (dispositions for fail-20260912-overnight-plan-accept-gate-kernel and
   fail-20260912-patrol-automation-gate: "transient gate reds",
   "self-heals each 30m tick").
2. **Green re-verified at disposition time.** Full `make test` run in
   hngh-automation 2026-10-08T14Z: rc=0, all suites OK, 296s wall. Cadence
   gate-check green 2026-10-08T09:05:31Z.
3. **Later re-fires are the same transient class, now self-diagnosing.**
   2026-10-07T09:04:58Z red captured its own output: 4 gate-lock test FAILs
   (held gate lock defers push / gate-lock-busy crumb / gate crumb / free
   gate lock re-runs the gate) — gate-lock self-interference while the
   cadence tick held the lock — self-healed by 2026-10-08T09:05Z. This
   matches the R2 recommendation in 2026-09-28-fail-20260913-gate-check-hngh.md
   (make rc=2 self-diagnosing at moment of action): output capture exists.
4. **Residual.** The recurring gate-lock flake class is owned by the parked
   research line `patrol-20260925-automation-gate-gate-stale`
   (parked untyped, 2026-09-26, with an executable discrimination
   instrument). This line adds no new action on it.

## Disposition mechanics

- Subject row appended to research-subjects.txt (was absent — none of the
  eight accepted plans under this identity ever landed the delve).
- Disposition row appended to research-dispositions.tsv (verdict killed).
- Plans ticked: 2026-09-16-routed-overnight-plan-accept-gate-automation
  {-1,-2,-3} (all three share the subject id and satisfied verification).
