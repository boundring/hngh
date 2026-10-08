# killed before research: fail-20260916-overnight-plan-accept-gate-automation

Status: closed 2026-10-08 (overnight-lead session). Alert identity
`overnight:plan-accept-gate:automation` — plan acceptance blocked:
hngh-automation make test FAILED (rc=2) ×3, routed 2026-09-16T19:00:34Z.

## Verdict

Killed — resolved before research. The 2026-09-15/16 rc=2 window self-healed
with zero automation commits and never reproduced with captured output.

## Evidence

Correction 2026-10-08T14:45:54Z: the first landed version of this doc claimed
"self-healed with zero automation commits" and classified the 2026-10-07 red
as lock self-interference. Both clauses were wrong (the first derived from a
bare-date git log with local-time rendering mixed against UTC breadcrumbs;
the second was unverified inference). Corrected in place below; the
superseding disposition row carries the same correction.

1. **Fixed by code, not self-healed.** 175 commits landed between route
   (2026-09-16T19:00:34Z) and acceptance (2026-09-18T01:41:57Z), including
   two automation fixes for CI-only test failures in 16-curator-beat:
   526c55cb (2026-09-18T00:50:01Z, gates on HNGH_PLANS_FEED_OUT not the
   untracked dashboard artifact) and c74ccabb (2026-09-18T01:02:32Z,
   defaults STATE_FILE — unset var + set -u aborted the wrapper before
   emit). Acceptance went green 40 minutes after the last fix. The exact
   causal link to the 09-15/16 rc=2 is attribution, not proof: the red rows
   (2026-09-15T09:01:13Z, 2026-09-16T09:01:12Z) captured no test output, so
   no archived artifact pins the failing suite. Best-available attribution
   stands; the condition itself is verifiably gone.
2. **Green re-verified at disposition time.** Full `make test` run in
   hngh-automation 2026-10-08T14Z: rc=0, all suites OK, 296s wall. Cadence
   gate-check green 2026-10-08T09:05:31Z.
3. **Later re-fires were a real defect, since fixed.** The
   2026-10-07T09:04:58Z red (4 gate-lock test FAILs: held gate lock defers
   push / gate-lock-busy crumb / gate crumb / free gate lock re-runs the
   gate) was failing-first test cases 6-7 in test-remote-push.sh left by
   dead 2026-10-06/07 sessions — a genuine 16-remote-push.sh lock-handling
   defect, fixed by f1477a40 (2026-10-08T04:25:22Z, defer remote-push when
   the gate-evaluation lock is held); reports.md progress row 71d87506
   (2026-10-08T04:31:55Z) records the unblock and the removal of the mass
   plan-block cause. Not a transient, not self-healing.
4. **Residual.** None open from this line. The parked research line
   `patrol-20260925-automation-gate-gate-stale` (parked untyped,
   2026-09-26) predates the f1477a40 fix and may be closable against it;
   that is that line's owner's call, not this one's.

## Disposition mechanics

- Subject row appended to research-subjects.txt (was absent — none of the
  eight accepted plans under this identity ever landed the delve).
- Disposition row appended to research-dispositions.tsv (verdict killed).
- Plans ticked: 2026-09-16-routed-overnight-plan-accept-gate-automation
  {-1,-2,-3} (all three share the subject id and satisfied verification).
