# Kernel gate capture — 2026-09-07T00:05Z

Plan: `2026-09-01-routed-overnight-plan-accept-gate-kernel`
Gate: hngh kernel `make test`

## Results

- hngh-automation `make test`: GREEN (rc=0, 8.28s)
- hngh kernel `make test`: RED (rc=1)

## Failing check

- **Test**: `test_dry_run_exits_zero_and_mutates_nothing`
  in `hngh/tests/scripts/test-schedule-heartbeat.py:39`
- **Assertion**: `self.assertNotIn("heartbeat-", timeline.md.read_text())`
- **Cause**: cadence docs contain "heartbeat" text — the test's negative-assertion
  invariant is violated by legitimate content in `docs/project/timeline.md`.
- **Fix scope**: touching `hngh/tests/scripts/test-schedule-heartbeat.py`
  (kernel test) — FORBIDDEN this session per plan autonomy rule.

## Parked

This check is parked. Next session: fix the test's negative-assertion
invariant to match the cadence docs' actual content.

## Resolution (2026-09-07T06:08Z wake)

The parked advice above is withdrawn — no test change is needed.

- Root cause was NOT legitimate timeline content:
  `scripts/schedule-heartbeat`'s `record_telemetry` appended
  `heartbeat-N` rows to `docs/project/timeline.md` on every live tick
  (kernel defect). The guard test is the standing law; the tick write
  was the defect.
- Fixed 2026-09-07T00:12:59Z by kernel ceremony commit `2749645`
  (tick no longer writes timeline.md). Cure record: hngh
  `docs/records/2026-09-07-heartbeat-timeline-guard.md`.
- Re-verified this wake: hngh kernel `make test` rc=0, 2855 checks
  passed (2026-09-07T06:03:16Z; again 06:08:07Z post-commit);
  hngh-automation `make test` rc=0 (2026-09-07T06:03:30Z). Plan
  acceptance resumed 2026-09-07T01:01:21Z; no `plan-blocked` rows
  since 00:31:14Z.
- Plan `2026-09-01-routed-overnight-plan-accept-gate-kernel` ticked
  executed and landed via ceremony commit `a1dd16b` (pushed to
  origin; kernel tree-skew cleared).
