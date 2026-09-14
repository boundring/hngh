# fail-20260910-slow-unit-dropin-16-remote-push.sh — slow-unit: dropin:16-remote-push.sh

- Date: 2026-09-14
- Alert: `[oversight] slow-unit: dropin:16-remote-push.sh wall=23.1s median=0.0s ×12`
  (routed 2026-09-10T03:00:18Z; the same identity kept firing — 432 rows
  through 2026-09-14T09:00:37Z, walls 28.6–40.8s)
- Question: is the wall latency a defect or expected beat work, and what
  disposition (fix or park) does the design support?

## Evidence read

- `automation/cadence/hour/16-remote-push.sh:84-108` — the slow branch:
  when the last gate crumb is red/none/stale AND commits are unpushed,
  the script re-runs the repo gate inline under `timeout 290 make test`
  (line 94) before pushing. The fast branch (`push-up-to-date`, line 68)
  exits in ~0s.
- `automation/cadence/day/03-gate-check.sh:44` — the day tier (≈09:00)
  is the only gate-check crumb writer. It recorded
  `gate-red | hngh: make test rc=2` at 2026-09-13T09:00:48Z; the next
  green kernel crumb is 2026-09-14T09:01:06Z (2894 checks). That 24h
  window put every push event on the slow branch.
- `automation/STATE.md` (grep `| 16-remote-push.sh |`): during the
  window, repeated `gate-refresh` → `push-done` pairs ~2s apart, i.e.
  the inline `make test` re-run went green each time. The 2026-09-13
  red itself never reproduced (matches ocgo-agent-lessons 2026-09-14
  08:12: kernel gate reds of that shape are transient).
- `automation/dashboard/time-ledger.json` (2026-09-14T09:03Z):
  `dropin:16-remote-push.sh last_wall_s=28.64, p50_s=0.016, runs_24h=23`.
- `automation/jobs/slow-units.py:24-27` — ENVELOPE already exempts the
  two timeout-capped bimodal units (`dropin:20-workbeat.sh`,
  `hngh-overnight.service` at 1800+60s) for exactly this failure shape;
  16-remote-push.sh was simply missing from the map.
- Prior art: research-dispositions rows 61-62 and 82 (the parked
  50-research-overflow and 33-research-beat cases) — same bimodal
  structure, parked there because the wall was single model-call
  latency a pacer already owns. Here the wall is a gate re-run the
  script itself owns, so the parallel fix is the envelope, not a park.

## Doctrine applied

- Delay-flagging doctrine (jobs/slow-units.py header): inside a unit's
  design envelope a wall is never slow; over it both rules flag. The
  envelope is the sanctioned way to say "bimodal by design" without
  weakening the median rule for everything else.
- Failing-test-first (hngh AGENTS.md engineering rules): the envelope
  change landed with two new cases in tests/test-slow-units.py that
  failed against the old map (observed walls flagged) and pass after.

## Findings

1. Not a defect in the beat: 28-41s is a green re-run of the kernel
   gate under the script's own 290s cap, doing exactly its documented
   job (never push on a stale/red gate signal).
2. The alerting was the defect: the median rule alone cannot classify a
   timeout-capped bimodal unit; ENVELOPE existed for this since
   2026-09-01 and 16-remote-push.sh was an omission from the map.
3. Amplifier, not cause: the 2026-09-13 transient kernel gate-red crumb
   pinned the slow branch for 24h, turning 4×/hour backstop + per-commit
   hook fires into 432 duplicate rows (dedup window 86400s is per
   identity, but each new wall re-armed it).
4. Escalation trigger kept: a wall over 350s (290 cap + 60 margin)
   still flags via both rules — a real regression (gate runaways) stays
   visible.

## Recommended next line

- Landed 2026-09-14: `dropin:16-remote-push.sh: 290.0 + 60.0` in
  `jobs/slow-units.py` ENVELOPE + `tests/test-slow-units.py`
  envelope cases (fix disposition, adopted).
- Watch: if `gate-rerun-*` logs in `automation/logs/` start showing
  repeated kernel-gate failures (not transient flaps), the cause is the
  gate, not the monitor — open a subject on the failing check, not on
  wall time.
- Optional later slice: have 03-gate-check.sh also write an
  hour-tier-staleness crumb so a day-old red crumb costs one inline
  re-run, not a state the slow-unit monitor must learn to forgive.
