# 2026-08-26 — Autonomy build slice finished (report-queue, run-autonomous)

## Scope

Completing the half-finished autonomy slice left uncommitted by the
prior session: the append-only report queue, the single-tick
`run-autonomous` governance driver, and their hermetic tests. No new
features.

## What landed

1. **report-queue**: `--list`/`--unread` rows are now real table rows
   (`| ts | kind | id | first | body-name |`) — the format the tests
   and the dashboard-readout consumer convention (`startswith("|")`)
   already expected.
2. **generate-publication**: restored the missing `import os` (a
   `NameError` at import had broken its whole suite 4/4); the
   `HNGH_PUB_ROOT` env override works again.
3. **run-autonomous** (`scripts/run-autonomous`): the finished
   single-tick autonomy driver — journal generation when today's
   journal is absent (progress + scheduled reports), one check-in-scale
   validation slice when the queue Next + >=2 open lanes + a valid
   heartbeat `.slice` card align (fresh `/tmp/hngh-auto-*` store),
   malformed cards fail closed (exit 2), refusing sub-steps exit 3,
   nothing-due exits 0. Date override `HNGH_TICK_TS` for tests.
4. **Hermetic tests**: `tests/scripts/test-report-queue.py` (8 checks,
   plus the fixed newest-first JSON body assertion) and the new
   `tests/scripts/test-run-autonomous.py` (6 checks over the full tick
   contract, stubbed siblings, no sbcl/network). Both wired into
   `make test`.

## Verification

- `python3 tests/scripts/test-report-queue.py` 8/8 ok (was 3 failures).
- `python3 tests/scripts/test-run-autonomous.py` 6/6 ok (new).
- `python3 tests/scripts/test-generate-publication.py` 4/4 ok (was 4 errors).
- `make test` full gate green.
- Live smoke: `HNGH_TICK_TS=2026-08-26 scripts/run-autonomous` →
  "nothing due", exit 0 (journal already present, gates shut).
- Landed through ceremony-drive (candidate
  `0765a7d00369d84af6df585c24a254852a7cb8e9cf8d1c72f8147d3197a75705`).

## Notes

- Ceremony-drive refused a store path whose root directory did not
  exist (TRANSPORT-FAULT); `mkdir -p` the store first.
- The hourly systemd timer wiring lives in the hngh-automation repo
  (`hngh-autonomy.timer`), left unenabled for the operator.
