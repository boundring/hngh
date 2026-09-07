<!-- plan: status=executed risk=normal accepted=2026-09-01T12:01:27Z routed-from=overnight:plan-accept-gate:kernel -->
# 2026-09-01 — routed candidate

Routed by scripts/router-tick.py from alert identity `overnight:plan-accept-gate:kernel`
at 2026-09-01T11:00:45Z. Alert text: plan acceptance blocked: kernel make test FAILED (rc=2) ×2

## Steps

- [x] Re-run the named gate, capture the failing check, fix or park
      Verification: both `make test` gates green; failing check captured

## Resolution (2026-09-07)

- Failing check captured 2026-09-07T00:05Z (hngh-automation
  docs/records/2026-09-07-kernel-gate-capture.md):
  `test_dry_run_exits_zero_and_mutates_nothing`
  (tests/scripts/test-schedule-heartbeat.py:48) —
  `assertNotIn("heartbeat-", docs/project/timeline.md)` failed because
  `scripts/schedule-heartbeat` ticks were appending `heartbeat-N` rows
  to timeline.md.
- Fixed 2026-09-07T00:12:59Z by ceremony `2749645`: the tick no longer
  writes timeline.md; cure record:
  docs/records/2026-09-07-heartbeat-timeline-guard.md. The 00:05Z
  capture's parked advice ("fix the test's negative-assertion
  invariant") is withdrawn — the test is the standing law, the tick
  write was the defect.
- Re-verified this wake: kernel `make test` rc=0, 2855 checks passed
  (2026-09-07T06:03:16Z); hngh-automation `make test` rc=0
  (2026-09-07T06:03:30Z). Acceptance resumed 01:01:21Z (five plans
  accepted); no `plan-blocked` rows since 00:31:14Z.
