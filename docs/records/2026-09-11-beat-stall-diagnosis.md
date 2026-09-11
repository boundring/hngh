# 2026-09-11 — delegated-session beat stall diagnosis

Symptoms: zero overnight-lead completions after 2026-09-11T06:39:13Z despite
healthy cadence ticks, failfirst green, and only 7/200 sessions used.

## What was NOT the cause (checked, cited)

- Timer/service: `hngh-overnight.timer` active, fired every 30m
  (OnCalendar `00/2:30`); the service ran and exited 0 each time (last
  invocation 14:36:00 EDT, status=0/SUCCESS). systemd lifecycle healthy.
- flock: no contention (`flock -n` failures would breadcrumb; none today).
- sessions-day-max: 7 rows against cap 200 (logs/budget.md) — fine.
- cold-start unclean crumbs: no shutdown-signal newer than the last
  overnight-done in automation/STATE.md (rows 32816-38210 show
  overnight-done at every beat through 18:36Z). The prime suspect did
  not fire.

## Root cause (a) + (b): one bridge store per beat, run-1 per store

hngh records exactly one run per store (`store-record-run`, src/adapter/
filesystem.lisp:117-124): a second create-run for run-1 in the same
record.lisp returns :conflict, rendered `conflict labels=record-conflict`.
`scripts/omp-bridge --run-start` (post-572d3e2) always creates run-1 in
OMP_BRIDGE_STORE. `overnight-cycle.sh` sets STORE once per beat process,
and `lib/launch-session.sh` used that same STORE for every launch — so
within one beat only the FIRST launch could be recorded; the dream pass
(forethought, landed 6119f33 2026-09-10T21:51-04:00) took run-1, the
executor's create-run refused record-conflict, rc=75, no session, no
spend, counted as launch-plane "failed".

Evidence: store `~/.hngh-automation/store/overnight-20260911T050114-514487/`
holds the 05:01 EDT dream's CREATION+ADMISSION+CLOSE for run-1; the 09:04Z
alert row (`report-queue` 260121eb) reads "could not open a bridge run:
conflict labels=record-conflict". Breadcrumbs 31768-38210: every beat
since 22:31Z Sep 10 shows results=failed for all launches except the
first-recorded one (01:10Z/04:11Z/06:39Z "failed,ok"). Repro (real
bridge): second `--run-start` against the same store → `conflict
labels=record-conflict` rc=1; per-launch store subdirs → both accepted.

Consequences: failfirst development state accumulated n_fail=9 (launch-
plane crashes, not session quality) → speed=3 (cautious), ceiling=1.
Symptom (b): the mutation lane (wake-mutation-lane, Queue Next) never
got a beat because selector (a) always outranked it with the accepted
worker-transport-wiring plan, whose every executor launch died on the
conflict; extra plan slots died the same way.

## Root cause (c): rc=124 timeout classified unknown -> non-transient

The 2026-09-06-worker-transport-wiring session died on the 1800s timeout
(rc=124) with a clean "Working..." log tail (logs/overnight-2026-09-06-
worker-transport-wiring-20260910T180100.log). classify_cause matched no
failure keyword -> cause=unknown; agent-respawn guard 1's default branch
called it non-transient -> respawn-refused 2026-09-10T23:00:32Z. A
timeout IS a transient death (steer-vs-die doctrine).

## Fixes (automation tier, test-first)

1. lib/launch-session.sh: `launch_store` gives every launch its own
   bridge-store subdir under the beat's STORE (run-end uses the same
   dir as its run-start). Tests: tests/test-ocgo-launch.py
   `test_second_launch_in_same_beat_store_is_not_refused`.
2. lib/causes.sh: `classify_cause log [rc]` — rc=124 with a
   failure-keyword-free tail classifies bad-execution (transient), a
   text-derived class still wins when present. Tests:
   tests/test-causes.py rc=124 trio.
3. docs/project/plans/2026-09-06-worker-transport-wiring.plan.md parked
   (status=parked, cause=ceremony-required): its open steps touch kernel
   src/tests and belong to the certificate-ceremony lane, not machine
   delegated sessions; step 1 already landed in e42f637. Alert row
   filed (identity overnight:park:2026-09-06-worker-transport-wiring).
   This unblocks the selector: the next tick can reach queued lanes.

## Next tick expectation

At the next hngh-overnight fire: no bridge-refused alert for the parked
plan; selector (a) picks another accepted plan (or (b) the queued
wake-mutation-lane lane); dream and executor both launch (distinct
stores); failfirst state recovers as oks accumulate. The failfirst state
file was left to self-heal — its 9 fails accurately record launch-plane
crashes that no longer occur.

## Notes

- Burst of empty bridge stores 09:12-09:46Z (~90 dirs, no record.lisp):
  create-run refused pre-record during the window src/ was mid-edit
  (kernel gate red); transient environment noise, not a code defect.
- Observed non-sequitur to watch: 16-remote-push.sh still refuses to
  push because the KERNEL make test is red (commit 572d3e2's subject
  violates the "hngh: candidate <hash>" convention check) — that is the
  kernel gate, operator/ceremony territory, untouched here.