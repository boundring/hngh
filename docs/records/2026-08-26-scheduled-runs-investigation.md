# 2026-08-26: scheduled-runs investigation

## Scope

A read-only investigation of the `hngh-automation` project directory (a
separate repo from the hngh kernel) and its Hngh store (under
`~/.hngh-automation/store`).
Trigger: the dashboard's session list showed only "hourly research ping"
runs, all `cancelled`, and the operator asked whether any scheduled jobs
were actually firing.

## Finding 1 — the schedule is healthy

The trigger is a **systemd user timer**, not cron (`crontab` is not
installed on this box):

```
systemd/hngh-automation.timer:
  OnCalendar=*-*-* *:00:00
  Persistent=true
  WantedBy=timers.target
systemd/hngh-automation.service:
  ExecStart=<AUTOMATION_ROOT>/jobs/ping-hourly.sh
```

Live timer state (`systemctl --user list-timers --all`): `hngh-automation`
NEXT 2026-08-26 02:00:00 EDT, LAST passed 01:00:49 EDT (19 min ago).
All `hngh-*` units are `enabled + active`, and every job's service
`Result=success`. There are **7 timers**: `hngh-automation` (hourly ping),
`hngh-security` (every 4h), `hngh-morning` (digest 06-09h), `hngh-night-agent`
(00/02/04/06), `hngh-night-research` (23:40), `hngh-model-bench` (01:10),
`hngh-morning-report` (07:30). Hourly snapshots, digests, research briefs,
and model-bench rows all exist for the current day — the jobs fire and
produce output.

## Finding 2 — every `cancelled` run is a beacon closed `cancelled` BY DESIGN

Every store run traces `create-run` → `close-run cancelled`, closed
explicitly in `lib/hngh-record.sh`:

```
record_hngh_run() {
  ...
  close_out="$( "$HNGH_CLI" --store="$run_store" close-run "run-$run" cancelled 2>&1 )"
```

A completed run's mission declares `EVACUATION-CONDITION "evacuated"`, yet
`close-run ... cancelled` was hard-coded, so **no run ever reached
evacuated/complete** — the dashboard faithfully rendered "all cancelled".
This is not a failure; it is a semantic mislabel of a deliberately
best-effort activity beacon.

Store trace of a fresh per-job store directory:

```
(:IDENTIFIER "run-1" :KIND :CREATION :STATE :CREATED ... :OBJECTIVE "hourly research ping 2026-08-25 2100" ...)
(:IDENTIFIER "run-1" :KIND :CLOSE :STATE :CANCELLED ... :RECEIPT (:KIND :CLOSE :FACTS ("closed-to-cancelled")))
```

## Finding 3 — 4 of 7 jobs never wrote a run

`record_hngh_run` appears only in `jobs/ping-hourly.sh`,
`jobs/security-check.sh`, `jobs/morning-digest.sh`. The night-research,
model-bench, night-agent, and morning-report jobs produced output but
created no run row, so the session view was blind to them.

Store census at investigation time: **42 run dirs, 42/42 `:CANCELLED`,
0 evacuated, 0 complete** — all beacons from exactly three job kinds
(hourly research ping, morning digest, security check). No worker,
rotation, or checkin runs exist in this store.

## Fixes applied (hngh-automation repo, commit in that repo)

- **FIX-1 (semantics):** `record_hngh_run` now drives the closed CLI
  sequence `create → admit-transport filesystem → arm → start → close
  evacuated` (evacuated is only legal from `:running`), landing
  `:EVACUATED`. Falls back to `close cancelled` when the lifecycle
  refuses (refusals are data). The best-effort dogfooding comment is
  preserved.
- **FIX-2 (visibility):** `scripts/night-session.sh` (covers night-agent
  + morning-report), `jobs/model-bench.sh`, and `jobs/night-research.sh`
  now call `record_hngh_run` with their own mission labels, so the store
  reflects all 7 scheduled jobs.

## Evidence

- `systemctl --user list-timers --all` (7 hngh timers, LAST/PASSED shown).
- Store trace above (per-job `record.lisp`, `CANCELLED`).
- Scratch-store proof: `record_hngh_run "scratch beacon probe"` with
  `HNGH_STORE=/tmp/beacon-test` landed
  `:STATE :EVACUATED` ×2 and `closed-to-evacuated` in the store.
- `bash -n` clean on `lib/hngh-record.sh`, `scripts/night-session.sh`,
  `jobs/model-bench.sh`, `jobs/night-research.sh`.

## Remaining unknown

The dashboard (`scripts/dashboard-readout` in the hngh kernel) still
labels these beacons as "sessions"; distinguishing "beacon (cancelled by
design)" from genuine sessions is a follow-up view slice, not part of
this record.