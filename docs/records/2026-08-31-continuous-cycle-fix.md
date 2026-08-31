# The continuous cycle and the plan-acceptance fix — 2026-08-31

Status: RECORD. Evidence cited per claim; admits no runtime capability.

Scope: interim review of the window 2026-08-30T19:26Z → 2026-08-31T03:21Z
(between the last kernel ceremony and the operator's 03:21Z direction),
the operator's standing direction that the plan-execution cycle is
continuous, and the fix that makes machine plan acceptance real.

## 1. Interim review 2026-08-30T19:26Z → 2026-08-31T03:21Z

- **Zero kernel commits; everything pushed.** HEAD is `8dfab6d`
  (2026-08-30T19:26:30Z, "hngh: candidate ef3c5861…"); `git branch -vv`
  shows `main` level with `origin/main` at the same hash — nothing
  landed and nothing unpushed in the window. (Precision note, added at
  landing time: after the §3 fix went live, the accepted
  evening-selfdev plan was machine-executed and its docs landed as
  kernel ceremony commit `c0bf428` at 2026-08-31T19:10Z — outside this
  review window, and itself pushed to origin/main. The fix
  demonstrably unblocks the pipeline this record describes.)
- **Both 2026-08-30 plans were never executed.** Front-matter of
  `docs/project/plans/2026-08-30-overnight-continuity.plan.md` and
  `docs/project/plans/2026-08-30-evening-selfdev.plan.md` still reads
  `status=proposed risk=normal accepted=-`; no `- [x]` step was ticked
  during the window (the two checked steps in the evening plan were
  marked by the author at authoring time, before the window). No
  rotation rows were added to `docs/project/timeline.md` (last rotation
  rows are 2026-08-25) and no next-day plan exists in
  `docs/project/plans/`. `hngh-automation/dashboard/plans.json` listed
  both as `status: proposed, accepted: -` — the machine saw them and
  correctly skipped them per its code.
- **Root cause: contract drift, not a fault.** The plan contract
  (`docs/project/plans/README.md`, "Acceptance") says a proposed
  normal-risk plan is auto-accepted when its verification steps are
  runnable and both gates are green. The executor
  (`hngh-automation/scripts/overnight-cycle.sh`) implements only the
  consuming half: selector (a) requires `status=accepted` (~line 180)
  and machine-drafted plans are written `status=drafted` with
  operator-accept instructions (~line 158). No code path anywhere in
  hngh-automation flips `proposed` → `accepted` (verified by search for
  auto-acceptance across `scripts/`, `jobs/`, `cadence/`). The plan
  contract and the executor drifted apart; the operator-only acceptance
  is the drift, not the contract. And there was no hour-gating either:
  the `hngh-overnight.timer` is `OnCalendar=*-*-* 00/2:30:00` — every
  2 hours, 24/7 — so the cycle was already running around the clock;
  the ONLY blocker was acceptance.
- **Zero new alert rows in the window.** `docs/project/reports.md`
  holds 25 alert-class rows in total (classes observed: oversight
  stale-store, review P0/P1, loop-signal, ui-audit, doc-suite check,
  agent-stall); none fall in the window. No alert class covers
  "plans staged but never accepted" — the highest-leverage failure of
  the night was invisible to the alert surface.
- **The no-daemon cadence itself ran clean all night.** `config-backup
  agent-configs` progress rows every 30 minutes through the window
  (19:30:45Z through 03:00:45Z, `6f20e8cb`, ok 9 files each); hourly
  research beats advanced lines all night; hngh-automation sweep
  commits landed hourly through 23:01 EDT (`cbae502` 19:01 …
  `d535f71` 2026-08-30T23:01:46-04:00 = 03:01:46Z).
- **Research crystallized four new docs in the window, all untracked:**
  gantt-legibility-patterns (20:04Z), search-grounded-research-beats
  (22:03Z), self-funding-paths (00:03Z), session-cost-display-formats
  (02:03Z). All four sit untracked in `docs/research/` — the
  crystallized→committed stall, third occurrence (foldback lesson 3,
  `docs/records/2026-08-30-lessons-and-foldback.md` §2.3: the
  crystallized→committed path stalls without a ceremony driver in a
  plan). One crystallization (session-cost-display-formats) had
  regressed to ungrounded C-kernel fiction and was rewritten grounded
  in this same batch (docs/research/
  2026-08-31-session-cost-display-formats.md, grounded rewrite).

## 2. Operator direction (2026-08-31, recorded faithfully)

- **The plan-execution cycle is CONTINUOUS, 24/7 by intent.**
  "Overnight" is a naming artifact of when the first implementation
  happened. Unattended research and development happen at any hour of
  the operator's 24-hour cycle.
- The operator usually keeps Eastern time and sleeps at night; the
  machine does not sleep the same way — parts stay awake via local or
  remote agentic sessions, procedurally chained commands, scripts, and
  services, within the no-daemon discipline.
- Standing intents: automation for project-management practices in the
  clean-architecture style; research into self-correcting automation
  loops and program states that pass altered versions of themselves to
  future iterations; continuous refactor welcome when it serves
  clean-architecture purpose; roguelike development standards
  maintained (death-and-replacement, handoff briefs,
  procedural-over-agentic).
- Long-run goals: Hngh schedules and optimizes scheduling for
  relatively arbitrary requests, queueing and completing them
  immediately or on an appropriate cycle; and a long-term
  biographic/documentary pipeline where Hngh maintains the notes and
  records for operator writing about Hngh's development.

## 3. The fix (hngh-automation)

hngh-automation gains machine auto-acceptance implementing the README
contract: a proposed plan with `risk=normal`, runnable verification
steps, and both repos' gates green is flipped to
`accepted=<UTC ts>` by the machine, with a progress row emitted.
`risk=critical` plans never auto-accept. Red gates emit alert rows
naming the failed check. Plan execution is evaluated every tick, 24/7,
per the operator's continuous-cycle direction in §2. The plan-feed
`steps_total` parser is fixed (it counts checkboxes only within the
first 2048 bytes of the file — both 2026-08-30 plans' `## Steps`
sections begin beyond byte 2048, so the dashboard showed
`steps_total: 0` for plans that have steps). Hermetic unit tests cover
the acceptance path. This record cites the change at
hngh-automation commit `b1e3e26` (local, master; no remote configured —
hngh-automation has no git remote, parked for the operator; the
`hngh-overnight.timer` executes the local working tree, so the fix is
live on the next tick), message "feat: machine plan acceptance per
kernel contract; continuous 24/7 cycle", 7 files +472/−17, `make test`
green (bash -n over cadence/jobs/lib/scripts, 10/10 hermetic acceptance
tests, identifier lint). Grounded specifics: `scripts/accept-plans.py`
is a new fail-closed acceptance engine — proposed + normal-risk + every
unchecked step carrying Verification + both gates green → atomic
front-matter flip plus a progress row via `scripts/report-queue` and
`logs/acceptance.log`; `risk=critical` parks with an alert; a red gate
or non-runnable verification emits an alert row naming the failed
check; a `DRY_RUN` seam. Wired into `scripts/overnight-cycle.sh`
immediately after the flock and before the `MAX_SESSIONS_DAY` spend
cap (acceptance is cheap and uncapped), with the continuity comment
"plan acceptance/execution evaluated every tick, around the clock".
Selector (a) is unchanged (`status=accepted` grep) and the
accepted→executed lifecycle flip pre-exists. `dashboard/plans.json`
regenerated (evening plan 10 steps/2 done, overnight plan 6/0).
Precedent for machine-authored status: the 2026-08-28 plan's
acceptance flip rode kernel ceremony commit `667a36b`.

## Sources

- `git log` / `git branch -vv` in this repo (2026-08-31): HEAD
  `8dfab6d`, `origin/main` at the same hash, nothing unpushed
- `docs/project/plans/2026-08-30-overnight-continuity.plan.md` and
  `2026-08-30-evening-selfdev.plan.md` — front-matter and unchecked steps
- `docs/project/plans/README.md` — the plan contract (auto-acceptance)
- `hngh-automation/scripts/overnight-cycle.sh` — operator-only
  acceptance (~lines 158, 180); no proposed→accepted code path
- `hngh-automation git log b1e3e26` — the acceptance fix commit and
  its file list (`scripts/accept-plans.py`, `scripts/overnight-cycle.sh`,
  `jobs/plan-feed.py`, `dashboard/plans.json`, `tests/test-plan-acceptance.py`,
  `CHANGELOG.md`, `Makefile`); the `hngh-overnight.timer` calendar
  (`OnCalendar=*-*-* 00/2:30:00`) read from the systemd unit state
  reported by the director
- `docs/project/reports.md` — progress/alert ledger for the window
  (config-backup 30m rows, research-line rows, 25 alert rows none in
  window, classes stale-store/review/loop-signal/ui-audit/agent-stall)
- `hngh-automation/dashboard/plans.json` — the machine's view of the
  plans (proposed, accepted=-, steps_total=0)
- `hngh-automation/jobs/plan-feed.py` — the 2048-byte head read that
  truncates the steps count
- `hngh-automation git log` — hourly sweep commits
  `cbae502`(19:01EDT) → `d535f71`(23:01:46-04:00) inside the window
- `docs/records/2026-08-30-lessons-and-foldback.md` — foldback lessons
  (plan queue as throughput governor; crystallized→committed stall)
- `docs/design/ledger-and-records-spec.md`,
  `docs/research/2026-08-28-session-cost-display.md`,
  `docs/research/2026-08-30-alert-to-work-routing-patterns-closing-the-self-observation-loop.md`
  — the model rewrite pattern and the cost-display grounding
- `scripts/dashboard-readout`, `scripts/dashboard-tui`,
  `hngh-automation/dashboard-server.py`, `hngh-automation/jobs/session-cost.py`,
  `hngh-automation/jobs/telemetry.py`,
  `hngh-automation/jobs/telemetry-report.py` — the real cost-display
  surfaces (Deliverable 1 grounding)
