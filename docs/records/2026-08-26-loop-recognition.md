# 2026-08-26 — Loop recognition (oversight, repeated-expensive-identical-work)

## Scope

The recognition + steering half of the general failure class
"repeated expensive identical work before/while it loops". The concrete
instance diagnosed is `verify-candidate` re-running the full gate on
identical inputs; the sibling `2026-08-26-fasttest-cache.md` record is the
prevention half (a `/tmp/hngh-fasttest-*` cache that makes the repeat a
cache hit). This record is the detection and redirection half: an oversight
probe that names the loop as it starts and a model rubric that steers to
interrupt-and-redirect instead of letting the repeat continue.

## What landed (hngh-automation `jobs/oversight-tick.sh`)

1. **`probe_test_loops`** — a procedural probe watching two observable
   signals of repeated identical work:
   - **STATE crumbs**: 3+ byte-identical breadcrumbs (same `job|event|detail`)
     from the same oversight/credential/ceremony job, consecutive for that
     job (a distinct crumb from that job resets the count), all within a
     30-minute window. Distinct from the pre-existing 2-only
     `probe_repeated_breadcrumbs` alert; job-scoping kills steady-state
     noise (the tick's own `tick`/`steer` crumbs and the clock-scoped
     per-minute model crumbs never trip it).
   - **Verify-cache markers** (optional/cheap, fail-open): 3+ fresh
     `/tmp/hngh-fasttest-<repo>-<sha256>.ok` markers for the same repo
     within 5 minutes — the uncached repeat the FastTestCache exists to
     prevent. Absent marker directory → silent no-op, never an error.
   On either signal it emits `alert loop-signal: <detail>` through the
   existing `alert()` report-queue sink plus a breadcrumb.
2. **Agentic rubric** — the `steer_leg` prompt sent to `STEER_MODEL` now
   carries the loop-recognition rule: if the recent STATE tail shows
   repeated identical job/step execution with no distinct progress,
   recommend `steer: interrupt-and-redirect with the specific next action
   (prevent the repeat as it starts)`; otherwise `steer: none`. The gated /
   timed (`STEERING_BEAT_MIN`, default 10) / fail-closed behavior and the
   `steer:` crumb format are unchanged.
3. **Cadence note** — `cadence/README.md` documents the probe + rubric.

## Verification

- **Live run (no false positive)** on the current tree: `jobs/oversight-tick.sh`
  exits 0, breadcrumbs `tick mode=timer` + `steer none (no STEER_MODEL)`,
  and `grep -c loop-signal STATE.md` is 0. During the run the FastTestCache
  sibling was actively writing `/tmp/hngh-fasttest-*` markers for its own
  temp test repos (`tmp*`, one marker each) — repo-scoped grouping correctly
  did **not** fire.
- **Fixture (probe fires)**: a temp `STATE_FILE` seeded with 3 identical
  consecutive `credential-health.sh | credential-health | loop retry` crumbs
  plus 3 fresh same-repo `/tmp/hngh-fasttest-looprepo-*.ok` markers; the run
  exited 0 and appended one breadcrumb:
  `alert | loop-signal: STATE 3x identical crumb from credential-health.sh: credential-health.sh ¦ credential-health ¦ loop retry /tmp/hngh-fasttest looprepo (3 markers in 5m)`.
- **Gates**: `make test` in hngh-automation (identifier lint) green;
  `make test` in hngh green (see ceremony-commit hash below).

## Commits

- hngh-automation: `13071ba` — oversight-tick loop-recognition probe +
  steer rubric; `a32a059` — cadence README note.
- hngh: this record, ceremony-bound (commit hash in the commit itself).

## Remaining unknowns

- The FastTestCache marker grouping counts distinct keys per repo within a
  5-minute window (the marker design collapses same-key re-runs to a single
  file, so exact re-touch counts are not observable from one stat — the
  probe is deliberately heuristic, marked with a `ponytail:`
  comment naming the ceiling).