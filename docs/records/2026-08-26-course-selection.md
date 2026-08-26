# 2026-08-26 — Machine-steered course selection lands in run-autonomous

## Scope

First slice of the machine-steered-backlog roadmap item: Hngh picks its
own next-best course for a ceremony tick rather than slavishly following
static queue Next. Choice + card mount only — no gate is bypassed.

## What landed

`choose_course()` added to `scripts/run-autonomous`, wired into `tick()`
ahead of the ceremony gate:

1. **Ranking.** In-queue lanes (the `## Next` block items first, then
   queued TSV rows) are scored by
   - mounted `.slice` card (carded lanes first),
   - ascending recency of last increment — the newest
     `report-queue --json` row whose body names the lane; never-
     incremented lanes rank as most-due (`0000-01-01…`) — then
   - queue Next order, then TSV order, as tiebreak.
2. **Course record.** `tick()` records the machine's pick as a
   `course <id>: <reasons>` progress report (e.g. "card mounted, last
   increment 2026-01-01T00:00:00Z") before driving the ceremony slice.
3. **Divergence.** On a course pick that differs from static queue Next,
   the mounted card for the coursed lane runs through `ceremony-drive`
   from a fresh ephemeral `/tmp/hngh-auto-<ts>` store — static Next is
   not followed. When nothing is courseable it falls back to the prior
   Next-card behavior, and the existing gates (queue Next present +
   `>= 2` open lanes + valid mounted card) are unchanged; exit codes stay
   0/2/3.

## Verification

- `python3 tests/scripts/test-run-autonomous.py` 7/7 ok — new case
  `test_course_prefers_mounted_older_lane_over_static_next`: queue Next
  names `lane-a` but `lane-b` shares a mounted card and has the older
  increment, so the tick records `course lane-b: card mounted, last
  increment 2026-01-01T00:00:00Z`, drives `lane-b`'s slice (`src/lane-b
  .lisp` in the ceremony stub argv, `src/lane-a.lisp` absent), exit 0.
- `make test` full gate green (lisp suite + all python suites).

## Notes

- The course report row is a `progress` row, consistent with the
  journal/ceremony records; the `scheduled` row still lands after a
  ran tick.