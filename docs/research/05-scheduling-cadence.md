---
category: scheduling/cadence
persona: The Chronomancer
status: seed
---

# Scheduling & Cadence — what hngh runs today

hngh schedules work as a **4-tier drop-in engine**: three systemd timers fire `automation/jobs/cadence-tick.sh` for the `subhour`, `hour`, and `calendar` tiers (automation/Makefile:19-23), and each tick runs every numbered drop-in in its tier directory in lexical order (automation/jobs/cadence-tick.sh:1-12). The tree is large and explicit: 23 subhour drop-ins (00-time-ledger → 59-unsloth-observe), 15 hour drop-ins (00-dashboard-self-review → 42-dashboard-introspect), and calendar/{daily 32, weekly 4, monthly 2} (automation/cadence/ directory listing). The calendar tier picks its sub-branch by wall clock: 05:00 daily; 06:00 weekly Mondays + monthly on the 1st (automation/jobs/cadence-tick.sh:15-18). Every drop-in's wall time is a time-ledger source (automation/jobs/cadence-tick.sh:103-111); single-flight is per-tier `flock -n` with a `tick-skip` crumb on contention (automation/jobs/cadence-tick.sh:81-87).

Cross-cutting throttle gates live in the tick itself: a **bailiff_check** halts every tier while the watch audit has findings (automation/jobs/cadence-tick.sh:49-58) and a RAM belt gates the rapid tier (:70-74). Inside drop-ins, cheap stamp self-gating paces work that used to own a tier (e.g. `05-readout.sh` runs at most once per 1800s via `STAMP="~tmp/.hngh-cadence-05-readout-last"`, after the 2026-09-24 tier collapse; automation/cadence/subhour/05-readout.sh:6-11). Budgets and pacing knobs live in `automation/cadence-params.tsv` (dispatch-day-max, sessions-day-max, introspect-min-gap-hours; automation/cadence-params.tsv:53-54,76) and are env-overridable. Per-drop-in **policy** is also coded: the research beat holds local-model work when the operator is using the machine (operator-active guard shifting to a quota leg; automation/cadence/hour/33-research-beat.sh:840-844), and the overnight plan selector buckets `priority=high` front-matter ahead of filename order with synth plans last (scripts/overnight-cycle.sh:649-675).

## Open questions for web research

1. Fixed-rate vs jittered vs load-aware scheduling on a personal always-on box — what do homelab schedulers do about catch-up and overlap?
2. Stamp-file pacing (`~tmp/.hngh-*`) vs systemd `RandomizedDelaySec`/`Persistent=` — failure modes of each (clock jumps, tmp cleanup, missed windows).
3. Precedent for lexical drop-in composition with per-job budgets and a global suspension gate (the bailiff) — cron.d, s6, or job-runner designs.
4. Operator-presence aware scheduling: input-idle detection and graceful yield patterns.
5. Calendar-tier semantics others use for "daily at 05:00" vs "weekly Monday 06:00" — anacron-style missed-run policy.

## Candidate external systems to survey

- systemd timers (Persistent/RandomizedDelaySec semantics)
- anacron / cron.d composition
- Ofelia (Docker job scheduler)
- Temporal (schedules + catch-up policy)
- Prefect / Dagster (schedule + budget semantics)
