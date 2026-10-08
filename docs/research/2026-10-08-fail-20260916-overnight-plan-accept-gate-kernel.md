# Why did plan acceptance fail with kernel make test rc=2 (x3) for identity overnight:plan-accept-gate:kernel, and is the blocker still open or already resolved?

Status: killed before research 2026-10-08 -- the 2026-09-16 red window resolved
before the 2026-09-18 acceptance. Research line
`fail-20260916-overnight-plan-accept-gate-kernel`, twin of the reviewed sibling
`fail-20260916-overnight-plan-accept-gate-automation`.

## The 09-16 red window resolved before acceptance

- Alert identity `overnight:plan-accept-gate:kernel` fired x3 on 2026-09-16:
  routed plans at 21:00:15Z, 22:00:19Z, 23:00:13Z, each carrying the alert text
  "plan acceptance blocked: kernel make test FAILED (rc=2)".
- Those same plans carry `accepted=2026-09-18T01:41:57Z`: acceptance requires
  both gates green (accept-plans.py runs KERNEL_GATE `make test` and
  AUTOMATION_GATE `make test`), so the kernel gate was green by acceptance.
- Between the last red tick and acceptance, the kernel test-fix chain landed
  (timestamps UTC):
  - 4ed7c6b8 2026-09-17T14:45:33Z stable-point snapshot before system restart
  - 77ec1727 2026-09-17T14:54:48Z loop-history guard errors='replace' for CI
  - 5ae03dc8 2026-09-17T15:01:58Z STATE.md restore (tests expect it tracked)
  - fee46a32..a3cd2e99 2026-09-17T15:20-15:23Z UnicodeDecodeError fix chain +
    exemption cleanup
  - fa60bf0a 2026-09-17T15:56:18Z probe-model-route HTTPError-is-live pin
  - cbcf800f 2026-09-18T01:06:52Z terminal kernel candidate, 35 min before
    acceptance

  The sibling alert `2026-09-15-routed-overnight-rehearsal-gate-refusal-kernel-loop-history-guard`
  names the same loop-history guard these commits fix.

## Is the blocker still open?

The 09-16 blocker: resolved. The rc=2 family: still reachable as a transient,
not as this alert.

- The exact 09-16 kernel rc=2 was never captured in output (acceptance.log
  rows carry no failure text), so the window's mechanism is inference from the
  fix chain and the documented rc=2 family.
- rc=2 has a second documented member: the load-correlated gate flap
  (accept-plans.py GATE_LOCK / ACCEPT_ISOLATED_GATE commentary -- parallel
  delegated sessions compiling during a gate evaluation). A captured instance:
  2026-10-07T09:04:58Z red with its own output showing 4 gate-lock test FAILs
  under concurrent cadence lock, self-healed by 2026-10-08T09:05Z.
- The flap trail is live: 777 `kernel-gate-red-rc2` rows in
  automation/logs/acceptance.log through 2026-10-08T19:02:34Z, interleaved
  with same-day green acceptances (2026-10-08T18:35:25Z accepted vs
  2026-10-08T19:02:34Z kernel-gate-red-rc2 -- 27 minutes apart, flap
  signature).
- Re-verification at disposition time: kernel `make test` rc=0, 2957 checks,
  52s wall (2026-10-08T19Z), minutes after the 19:02:34Z red row.

## Disposition

Alert fixed (killed before research). The residual transient flap stays owned
by the accept-plans mitigation lane (GATE_LOCK flock serialization +
ACCEPT_ISOLATED_GATE rehearsal on a git-archive copy); re-open as a fresh
research line only if a captured kernel rc=2 reproduces with real test
failures rather than gate-lock contention.
