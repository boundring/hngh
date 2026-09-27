# 2026-09-13 governed-fleet slice C -- one witnessed delegation cycle + seeded stall auto-replace

Filed by the governed-fleet slice C landing (plan `governed-fleet-consolidation`,
2026-09-27 execution). The design surface is docs/design/governed-fleet.md
(section 4 row 7 line 147; section 6 slice C lines 240-243); this record cites
the evidence rows, it does not restate the design.

## What was witnessed (one real cycle)

One real delegated session ran the full launch cycle through `launch_session`
(automation/lib/launch-session.sh, header lines 1-25; the ONE gated launcher
per its own contract) into a FRESH launch store
(`~/.hngh-automation/store/slicec-beat-slicec-witness-20260927T131759-385658/launch-slicec-witness-*/`,
fresh per launch-store rule, launch-session.sh lines 66-75):

1. run-start: bridge `--run-start` against the fresh store, first event
   `:KIND :CREATION` (`record.lisp` line 1), then `:KIND :ADMISSION` (worker
   transport, scope repository, route model). The launcher owns these; the
   witness verified the record file directly after launch.
2. the session ran real work: it executed
   `tests/test-agent-supervision.py` and `tests/test-agent-respawn.py` inside
   itself and printed `slicec-witness verdict rc=0 0`
   (automation/logs/overnight-slicec-witness-20260927T131800.log line 9) —
   both supervision suites green from within a delegated session, so the
   slice's supervision minimum (automation `make test` minimum, plan step C
   sanity 3) is doubly witnessed.
3. run-end with the vocabulary mapping: `LAUNCH_DISPOSITION=complete`,
   cause `unclassified` (two-stage classifier: no failure-shaped line in the
   tail), bridge run closed with `:STATE :CANCELLED` (the complete→cancelled
   mapping landed in launch-session.sh lines 540-552, witnessed live rather
   than re-fixed — the stale-attempt hazard explicitly cleared off).

Ledger evidence: `logs/budget.md` row 265 (2026-09-27T17:18:24Z,
`overnight|slicec-witness | session-run | class=T2 | model=opencode-go/glm-5.3-flash | source=env`).
The dashboard observatory ran while the cycle was live and after it
(`jobs/refresh-dashboard.sh`, breadcrumbs `refresh-dashboard.sh | sessions-feed |
sessions.json refreshed`); the roster row class lives in
`dashboard/sessions.json` (54 launch-store rows at the scan time,
including the two earlier cancelled witness attempts from the morning's
stale-store stores — the obsolete blocker class that first created this
lane).

Handler rows in `agent-handoffs.md`: the complete row (rc=0, cause
unclassified) and the dead rows below, written by the same handler printf
the overnight-cycle handlers use (scripts/overnight-cycle.sh lines
1085-1094 verbatim shape).

## The seeded stall and the auto-replace decision

A second real delegated session was launched with `TIMEOUT_S=75` on an
honestly slow survey brief: the launcher's `timeout` killed it (rc=124),
the launcher classified `LAUNCH_CAUSE=bad-execution` (rc=124 → transient by
doctrine, lib/causes.sh line 44), emitted budget row 266 + handoff dead row
17:22:29Z. The real 5m supervision tick (cadence/subhour/45-agent-respawn.sh,
stamp /tmp/.hngh-cadence-45-agent-respawn-last) acted:

- first action: `respawn-refused` on guard 3 —
  `reason=day-budget-spent sessions-today=12 cap=4` (agent-handoffs.md
  line 1309, 17:28:11Z). The refusal is REAL evidence of a cap-source bug:
  agent-respawn.sh line 54 read the `OVERNIGHT_MAX_SESSIONS_DAY:-4` legacy
  constant and never the Inventory row (`sessions-day-max` = 200), while
  overnight-cycle's chain reads env > row > 4 (scripts/overnight-cycle.sh
  lines 36-43). Refusal-by-stale-constant is not a park; it is a bug the
  tick just surfaced.
- fix (automation free-commit): agent-respawn.sh line 54 now reads
  `MAX_SESSIONS_DAY="${OVERNIGHT_MAX_SESSIONS_DAY:-$(get_param
  sessions-day-max 4)}"` — the same chain as overnight-cycle; the row's
  non-objective "the spend ceiling is a hard constraint above this tuning"
  stays intact (the Inventory row IS the ceiling, both legs now honor it).
  Hermetic gate: `tests/test-agent-respawn.py` 9 tests green after the
  patch.
- re-seed (second stall, slug `slicec-stall-two`, timeout 45, budget row
  267, handoff dead row 17:30 second action): the next live tick runs the
  same guards against the fixed chain — [TICK2-PLACEHOLDER]
- applicability of guard 2/4 unchanged: only transient causes respawn
  (bad-execution), one attempt per mission per day, daily cap 1 respawn
  (row `respawn-daily-cap` = 1), launch only via lib/launch-session.sh.

## Kernel damage: none

No kernel `src/`, `tests/`, `Makefile`, or `hngh.asd` file is touched; the
staging boundary stands. Kernel `make test` green at the landing beat
(2954 checks passed; /tmp gate log 2026-09-27T13:16-13:19 UTC run).
