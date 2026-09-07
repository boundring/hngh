# 2026-09-07 -- Heartbeat timeline guard: same-day contradiction cured

## The contradiction

`scripts/schedule-heartbeat` and its own guard test
`tests/scripts/test-schedule-heartbeat.py` contradicted at HEAD. The
tick's `record_telemetry` appended a machine row
(`DATE<TAB>event<TAB>heartbeat-N<TAB>digest`) to
`docs/project/timeline.md` on every live tick, while the guard test
(line 48, landed in the same candidate `17260b1` that introduced the
tick) asserts timeline.md must NEVER contain `heartbeat-`. Live tick
`e744b3e` ("docs: heartbeat #1") wrote the first offending row;
`ee199a8` ("docs: heartbeat #2") wrote a second. `make test`: 4 tests,
1 failure, rc=2. The red gate blocked `scripts/accept-plans.py`
admission (it runs `make test`), blocking all plan acceptance.

## Which side was wrong: the tick

The test is the standing law; the tick's timeline write is the defect.
Evidence from the documented design:

1. `docs/project/timeline.md` (its own words, "Planned entities (to
   add, not yet built)"): "`timeline-events` (machine-readable ledger
   line per rotation) -- queue candidate proposed, not built." The
   periodic machine-line ledger is explicitly NOT part of the built
   design; the tick unilaterally invented one.
2. Same file, "## Timeline events": rows are appended "per
   rotation/event"; `scripts/rotate-queue` appends per rotation and
   "check-ins may append `event` rows". The heartbeat tick is neither
   a rotation nor a check-in; nothing licenses it as a writer.
3. `docs/project/checkin.md` header: "One entry per check-in,
   appended dated" -- checkin.md is the periodic ledger, and heartbeat
   entries were already landing there by design (heartbeat #1 and #2
   both have checkin sections).
4. `docs/project/queue.md` scheduling section: the tick "records a
   dated heartbeat entry with SHA-256 verification" -- no timeline.md
   mention anywhere in the heartbeat design (nor in
   `docs/project/heartbeat/README.md`).

## The cure (this candidate)

- `scripts/schedule-heartbeat`: `record_telemetry` no longer appends
  to timeline.md (checkin.md recording and its SHA-256 re-read
  verification are untouched); `heartbeat_number()` now counts
  `heartbeat #N` headers in checkin.md instead of `heartbeat-N` rows
  in timeline.md; `commit_ledger` stages only checkin.md; the
  docstring states the rule (checkin.md is the periodic ledger, never
  timeline.md).
- `docs/project/timeline.md`: removed the two stray `heartbeat-N`
  rows (noise in the milestone ledger); the checkin.md records stay.
- This record.

Landed through the dogfood ceremony: create-run (operator loadout,
local route, mutation tool label, no network) -> admit-transport
run-1 filesystem repository -> propose under the ten closed
principles (one claim-proof evidence requirement per principle;
verdict admitted) -> issue-cert prepare-candidate + mutation-check
(git add) -> issue-cert commit + mutation-check (fixed-message
`hngh: candidate <hash>`).

## Verification

- `make test`: green, 0 failures (guard test passes with the guard
  intact).
- `python3 tests/scripts/test-schedule-heartbeat.py`: 4 tests, ok.
- `DRY_RUN=1 scripts/accept-plans.py`: kernel-gate no longer red;
  admission verdict recorded in the run output.
