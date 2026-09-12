# 2026-09-12 — throughput evidence review (plan 2026-09-09-automation-schedule-optimization, step 4)

Question
--------
Does the last-7-day beat data support a cadence-param or sessions-day-max
adjustment, or is the current send throttling actually protecting against
degraded cascades (go/no-go per plan step 4)?

Evidence read
-------------
- `automation/STATE.md` `overnight-done` aggregate crumbs, rows from
  2026-09-09T00:22Z to 2026-09-12T19:32Z (format drift guard: aggregate
  rows with `sessions=N concurrency=N speed=N results=` exist only from
  2026-09-09; the 2026-09-05..09-08 window carries the older per-session
  `rc=` format and was EXCLUDED, not averaged — so "last 7 days usable"
  is really last 4 days of aggregate crumbs, 23 beats / 43 sessions).
- `scripts/overnight-cycle.sh:44-48` — `MAX_SESSIONS_DAY` =
  env override else Inventory `sessions-day-max` = **200** (was 8).
  At 43 sessions/4 days (~11/day) the ceiling is nowhere near binding;
  slots_day is not what constrains batch size.
- `scripts/overnight-cycle.sh:699-791` — result vocabulary confirmed
  from source, not assumed: `ok` = rc=0 with non-empty log;
  `degraded` = dead (rc!=0/timeout) or cancelled with no output;
  `failed` = launch-plane crash (bridge refusal, rc=75).
- `lib/failfirst.sh:1-45,120-135` — ladder semantics: speed
  full(1)/standard(2)/cautious(3) maps to concurrency 3/2/1
  (`failfirst-dev-concurrent-*` rows); degraded demotes one level
  immediately, failed drops to cautious and alerts; ok promotes after
  3 consecutive oks. Durable state in `state/failfirst/failfirst-development`:
  currently `speed=2 n_ok=13 n_deg=3 n_fail=9` — the ladder self-demoted
  after the 2026-09-11 failed cascade and is recovering.
- `logs/acceptance.log` — 161 `gate-red` rows through
  2026-09-12T20:01Z (`automation-gate-red-rc2` on three routed plans /
  kernel-gate equivalents): the load-correlated gate flap of plan step 5
  is still live and is a large share of the `degraded` outcomes.

Findings
--------
Counts (aggregate crumbs only):

| day    | beats | sessions | ok | degraded | failed |
|--------|-------|----------|----|----------|--------|
| 09-09  | 6     | 15       | 9  | 1        | 3      |
| 09-10  | 4     | 6        | 2  | 2        | 2      |
| 09-11  | 7     | 11       | 4  | 0        | 7      |
| 09-12  | 6     | 11       | 8  | 2        | 0      |
| total  | 23    | 43       | 23 | 5        | 12     |

Non-ok rate 18/43 = 42% overall; degraded 5/43 = 12%; failed 12/43 = 28%.

Per speed tier (state at beat time):

| tier | sessions | ok | degraded | failed | clean rate |
|------|----------|----|----------|--------|------------|
| speed 1 (concurrency 3) | 18 | 9 | 4 | 5 | 50% |
| speed 2 (concurrency 2) | 16 | 10 | 1 | 5 | 62% |
| speed 3 (concurrency 1) | 9  | 6 | 1 | 2 | 67% |

Go/no-go: **NO-GO — data does not support a tuning change.** Both prongs
of the plan's condition fail:

1. Degraded rate is NOT flat across tiers — it is 22% at speed 1
   (concurrency 3) vs 6%/11% at speeds 2/3. Parallel full-speed slots
   measurably produce fewer clean sessions per session, consistent with
   the step-5 gate-flap evidence (3 parallel SBCL compile sessions
   interfere on one host). Raising concurrency or the ceiling would
   push more sessions into the observed failure mode, not more throughput.
2. Slots are not "unused" — concurrency equals the ladder tier every
   beat; the beats that ran 1-2 slots ran them because the state
   machine demoted after failures (`n_fail=9` in the development
   state file). The low concurrency after 2026-09-11 is the safety
   mechanism working as designed, not idle capacity.

Doctrine applied
----------------
- Spend-ceiling invariant: `sessions-day-max` is a hard constraint that
  never moves (sessions-day-max row, operator authorization 2026-09-09);
  no case for touching it at 11 sessions/day against a 200 ceiling.
- Fail-first pacing invariant: optimization must not reduce safety
  (plan guardrail); both measured signals say the throttle is earning
  its keep.
- Format-drift guard honored: pre-2026-09-09 per-session crumbs
  excluded, not mixed into the sample.

Recommended next line
---------------------
The lever that would actually raise clean-session throughput is step 5
(gate-evaluation isolation under parallel beats): 12 of 18 non-ok
sessions in the window are `failed` launch-plane or acceptance-gate
flaps, still filing 161 `gate-red` rows through tonight. Fix the flap
first, re-measure a full week under a stable gate, and only then ask
the concurrency question again. Step 4 ends here with no code change.

Blocker note: `blk-20260912-2026-09-09-automation-schedule-optimization`
(active, cause unknown, 2026-09-12T19:32:58Z) sits on this lane from the
prior attempt that died in the log tail; this session completed the
analysis read-only and did not clear or re-raise the blocker — the
orchestrator owns the ledger.
