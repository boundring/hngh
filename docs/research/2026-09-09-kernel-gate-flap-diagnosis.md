# 2026-09-09 kernel gate flap - diagnosis and fix

Status: resolved. The kernel gate is green as of the fixes below;
`make test` rc=0, 2855 checks, at 2026-09-09T23:0xZ (post-fix) and
rc=0 again after the automation fix.

## The reported state vs the measured state

The operator report said the gate had been red continuously since
~17:55Z (about five hours). The ledgers say otherwise - the gate was
INTERMITTENTLY red all day, and what persisted for hours was a latch,
not the gate:

- kernel-gate-red-rc2 acceptance blocks: 02:31 (x8 occurrences
  02:31-05:01), 14:01, 14:31, 19:01 (acceptance.log rows).
- gate GREEN at: 15:01, 20:01, 21:01 (acceptance ran `make test` and
  accepted six plans and rehearsal-lane at those ticks - acceptance
  runs both gates and blocks on red, so these are proofs of green),
  plus isolated operator runs 16:58 and ~20:05 (2855 checks), plus
  this session's runs at ~22:45 and post-fix.
- the day-tier 03-gate-check ran once (09:00:49Z), measured rc=2, and
  wrote the last hngh gate crumb: `gate-red | hngh` (automation/STATE.md).

## Root cause (the real intermittency)

The failing test is
`tests/scripts/test-dashboard-live.py::test_rich_watch_renders_operative_and_quits`:
it starts `scripts/dashboard-readout --watch 1` on a pty, writes `q`
after 3.0 s, then `p.wait(timeout=5)` (line 168). The alert bodies
(docs/project/report-bodies/2026-09-09T09:00:49Z-alert-9794a623.md and
the 02:31 acceptance row) name the exact command and the
TimeoutExpired after 5 seconds - this wait, not a lint or an SBCL
failure. Make then exits 2 on the failed recipe.

Why the child sometimes does not exit within 5 s of `q`: in
`rich_watch` (scripts/dashboard-readout), the quit key is read at the
BOTTOM of the loop iteration. The iteration body's slow part is the
cold `session_rows` refresh: the newest five stores in
~/.hngh-automation/store (1514 stores today) each rendered by a serial
`sbcl --script scripts/hngh present run-1` subprocess with timeout=4.
Under beat-time load (three parallel delegated sessions each running
make test's SBCL compiles, plus ceremonies and dashboard ticks), SBCL
boots stretch past their budgets; the cold refresh then costs up to
5 x 4 s serial, and a `q` written during it sits unread. Measured at
quiet load this session: full json spine 0.7 s, cold session_rows
0.61 s, quit latency 0.05 s - and the flaky test green. The failure
shape is therefore a wall-clock race, load-correlated exactly as the
schedule-optimization plan's step 5 hypothesized (kernel-gate-red-rc2
and automation-gate-red-rc2 during parallel beats), with the race now
pinned to one test and one slow reader. Not OOM, not a working-tree
effect (it failed on the overnight trees and passes on the current
dirty tree), not an environment difference between systemd and shells
(it failed in both the acceptance subprocess and the day-tier check).

Hypotheses discriminated: (a) real flaky test under load - CONFIRMED,
test named above; (b) SBCL memory pressure - rejected (no OOM shape in
any alert body; the trace is a clean TimeoutExpired); (c) working-tree
state - rejected (green on dirty tree at 22:45Z, red on clean overnight
trees); (d) systemd env difference - rejected (both contexts fail the
same way at loaded times, both pass at quiet times).

## The latch (why "red" persisted for hours after recovery)

1. Push refusals: 16-remote-push.sh treats a red crumb as a standing
   prohibition and only the day-tier gate-check writes new crumbs - so
   the 09:00 red crumb refused every push (post-commit and hourly)
   from 09:00 to past 22:00 despite a green gate most of that window
   (push-refused rows: 18:32 through 22:00, including after the 20:01
   and 21:01 gate-green acceptances).
2. Oversight re-alerts: jobs/oversight-tick.sh probe_gate_red
   re-surfaces the unread gate-check:hngh alert row hourly within its
   24 h window - the "gate-red" observations at 17:55-22:45 in
   docs/research/2026-09-09-post-wiring-observation.md are this probe,
   not live measurements.
3. Queue starvation: with no runnable proposed plans left after 21:01,
   the remaining blocker was the failfirst development throttle at
   speed-3 (THROTTLE rows 21:01:37 onward), not the gate; the gate
   flips acceptance, failfirst and the session ceiling flip execution.

## Fixes landed (both through certificate ceremonies, both gates green)

1. scripts/dashboard-readout (ceremony commit deebe2c, candidate
   221de89d..., pushed): rich_watch now checks stdin FIRST each loop
   (0.2 s select, render paced by an interval gate) so a pending `q`
   never waits behind a refresh; session_rows renders the newest
   stores concurrently (ThreadPoolExecutor) so a cold refresh costs
   one timeout round (~4 s worst, 0.15 s measured) instead of five
   serial rounds (~20 s worst). Measured: cold 0.61 s -> 0.15 s, quit
   latency 0.05 s, test-dashboard-live 10/10 OK, full kernel gate
   rc=0 (2855 checks).
2. automation/cadence/hour/16-remote-push.sh + new
   automation/tests/test-remote-push.sh + Makefile wiring (ceremony
   commit f1365aed..., pushed, test-first): a red crumb now re-runs
   the repo gate inline (exactly what the crumb itself demands) and
   pushes on fresh green with a gate-refresh crumb; a genuinely red
   gate still refuses. The 14 h push freeze cannot recur. Full
   automation `make test` rc=0.

## Routed remainder (kernel tests/ - outside machine authority)

The test-side hardening belongs to
tests/scripts/test-dashboard-live.py:168: raise `p.wait(timeout=5)`
to a load-tolerant budget (30 s) or drain-read after `q`. tests/ is
inside the 2026-09-03 staging boundary: machine sessions do not touch
it without the certificate-bound :wake-mutation lane
(records/2026-09-09-operator-flexibility-doctrine.md section 2). The
script-side fix removes the known stall source; the test-side change
is the belt-and-suspenders rung and should ride the next
:wake-mutation-lane ceremony slice with exactly this citation.

## Reproduction matrix (what this session ran)

| When (UTC) | What | Result |
|---|---|---|
| 22:45 | make test, real dirty tree, quiet load | rc=0, 2855 checks, 37.5 s |
| 22:50 | test-dashboard-live.py under 8-burner load | OK (load 3.5 too low) |
| 22:52 | component timing (json spine, cold readers) | 0.7 s / 0.61 s - race not reproducer |
| 22:54 | quit-latency probe, quiet | 0.05 s |
| 22:56 | quit-latency probe under 3x make test | 0.05 s (compile phase not ramped) |
| 22:58 | session_rows under 36 concurrent SBCL boots | 0.62 s (synthetic load too weak) |
| - | alert-body forensics (report-bodies rows) | TimeoutExpired on the 5 s wait, named command |
| 23:05 | code path analysis (rich_watch, session_rows) | 5 serial SBCL subprocesses, timeout=4 each |
| 23:06 | fix applied; full kernel gate | rc=0, 2855 checks, 24.9 s |
| 23:12 | automation gate after latch fix | rc=0 |

The synthetic-load reproductions undershot the beat-time contention
(16 cores absorb toy burners); the causal chain rests on the alert
bodies naming the exact wait, the failure timestamps aligning with
loaded beats, and the quiet-time measurements showing the margin that
load erodes. The fix removes the stall source structurally rather
than re-tuning the race.


## Archive-gate immediate failure (2026-09-10 addendum)

The report of pushes refused since 23:51Z on gate-rerun logs showing
`make[1]: *** [Makefile:2: test] Error 1` inside /tmp/tmp.*/c4 was NOT
a kernel gate failure and NOT an archive problem. Two findings:

1. 16-remote-push.sh never runs `git archive`; its inline re-run is
   `cd "$KERNEL" && make test` in the real repository. The
   /tmp/tmp.XXX/c4 path in those logs is a TEST FIXTURE repository
   from automation/tests/test-remote-push.sh (case 4's sandbox,
   Makefile = `test:
@exit 1`), not the kernel.
2. The script wrote its gate output to a FIXED shared path
   (/tmp/hngh-gate-rerun-<name>.log) and moved it into
   automation/logs on failure. Concurrent invocations (hook-fired
   after ceremonies, hour ticks, and the test's own failing fixtures)
   shared that one file: the test's failing fixture repos (37/145-byte
   outputs) were moved into automation/logs as if they were kernel
   gate evidence, overwriting/mixing with real beat captures. The
   20 small logs were fixture residue; the three 7146-byte logs are
   real beat failures - all three are the known watch-quit race at
   tests/scripts/test-dashboard-live.py line 168 (routed residual,
   unchanged).

Fix (test-first, in test-remote-push.sh + the script):

- gate log is now per-invocation
  (/tmp/hngh-gate-rerun-<name>-<pid>.log) - no shared path, no
  clobber;
- failure logs land in $GATE_RERUN_DIR (default automation/logs),
  so the test harness sandboxes its fixtures and asserts
  automation/logs gains nothing during the run;
- fixture-contaminated logs purged (20 files); the 3 genuine beat
  captures retained.

Consequence for the push-refusal chain: the "immediate Error 1"
evidence was fixture output, not the kernel gate failing instantly.
The real refusals trace to genuine in-beat rc2 (the routed watch-test
budget fix) plus the red-crumb latch (already fixed). Pushes
themselves were not broken: the beat logs show gate-refresh green ->
push-done at 00:00:42Z, and the current backlog is one ledger-sync
commit.
