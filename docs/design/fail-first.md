# Fail-First

Status: DESIGN — 2026-09-07, implemented (hngh-automation lib/failfirst.sh).
Self-tuning replaces pre-set throttles for cycled operations.

Cross-links: [descent.md](descent.md), [gate-inventory.md](gate-inventory.md),
[ttsr-alignment.md](ttsr-alignment.md), [subsystem-anatomy.md](subsystem-anatomy.md).

## The doctrine

Run at maximum natural speed. Detect failure empirically. Self-tune to just
below the observed failure point. Measure always.

Every pre-set throttle in the research machine was a guess about where the
ceiling is. The guesses did not prevent failures — the model chain's
fail-closed-skip already degrades gracefully (model timeout -> next leg ->
archive-only -> exit 0, descent.md §control-plane invariant). What the
guesses prevented was MEASUREMENTS: a beat skipped by a stamp gate produces
no evidence about whether the machine could have run. Fail-first inverts the
burden: the throttle must be earned by an observed failure, not granted by a
configured interval.

The operator's framing: why can't Hngh just work as fast as it's able to,
when it's able to?

## TCP congestion control

The tuning state machine is TCP congestion control for research:

- **Slow start / full speed.** Fresh state starts at `full` (speed 1): the
  operation runs every tick. No stamp gate, no pacing.
- **Multiplicative decrease.** One `degraded` outcome (the model chain
  exhausted every leg — archive-only) demotes one level immediately:
  full -> standard -> cautious. Pacing multiples of the operation's tick:
  standard = every 2nd tick, cautious = every 4th.
- **Additive increase.** `failfirst-promote-threshold` (Inventory, default 3)
  consecutive `ok` outcomes at a paced speed promote one level back toward
  full.
- **Loss is not congestion.** A `failed` outcome is a real script bug, not
  saturation: drop the operation to `cautious` AND file a report-queue alert.
  Bugs get fixed, not paced around.

The state persists per operation in a key=value state file
(`$FAILFIRST_STATE_DIR`, default /tmp/hngh-failfirst). Loss of the state file
returns the operation to full speed — the safe direction for an
empirically-gated machine.

## What it replaces

The pre-set pacing family, removed from the Inventory:

- `research-beat-hours` — the hour beat's stamp gate. The beat now fires
  every hour tick; `failfirst_gate` decides GO vs THROTTLE.
- `research-overflow-hours` — the overflow beat's own stamp gate, replaced
  by its own tuning state at a 15-minute cadence.
- `research-review-interleave`, `research-demand-floor` — their Inventory
  rows are gone (they were pacing guesses), but the mechanisms stay as
  coverage and supply with in-script defaults (3 and 3, env-overridable).

## What it preserves (these were never throttles)

- **The fail-closed-skip chain** (lib/model.sh, untouched) — the failure
  detector. Degradation is observed, never injected.
- **External quota pacing** — kimi/lobehub daily caps and window pacing are
  external constraints, not internal guesses. A pace-blocked pinned leg
  falls through to the local chain; overflow beats past cap serve from the
  local server, measurably.
- **The demand synthesizer and review interleave** — supply and coverage,
  not speed limiters.
- **Capacity routing, not throttling** (operator refinement, 2026-09-07):
  loadavg1 >= `research-load-ceiling` * nproc and deck availability are
  ROUTING signals. Busy local shifts the pin — deck first when armed AND
  responsive (the `deck_up` /health probe; any HTTP answer counts, transport
  failure falls through), else a quota leg by run parity. The beat never
  defers: the machine never stops researching because the desktop is busy;
  it routes around it.
- **The run counter, quota rotations, review-always-pins-kimi** — capacity
  distribution and judgment routing, not throttles.
- **One-transition-at-a-time** — a shared `flock` in the beat body (replaces
  the old 30-minute stagger guard, which a 15-minute cadence would violate
  every tick). Race prevention, not pacing.

## Cadence

The 30m-tier overflow drop-in promotes to a full research beat at a
15-minute cadence: it runs the same beat body immediately and again 15
minutes later, so transitions land at :00 :15 :30 :45 — always pinned
non-local (deck first when responsive, else kimi/lobehub alternating). The
hour-tier beat keeps the local pin for research that benefits from the
local model. At full speed: 4 overflow transitions plus the hour beat's
local transition per hour; the tuning states pace each operation down just
below its own observed ceiling independently.

## Tuning state machine

```
              degraded                     degraded
  full (1) -----------> standard (2) ---------------> cautious (3)
     ^                     |   ^                          |
     |    3 consecutive    |   | 3 consecutive            | script
     |    ok outcomes      +---+ ok outcomes              | error
     |                     |   (promote one level)         |
     +---------------------+-------------------------------+
```

`record_outcome <op> <speed> <result>` after each run: ok = the model_call
returned content; degraded = archive-only; failed = the script errored (the
EXIT trap). `failfirst_gate <op> <state-file>` echoes GO or
THROTTLE:speed-<n> and writes the run stamp on GO.

## Instrumentation

`cadence/day/20-model-saturation.sh` appends the tuning state summary to
its daily utilization row: current speed per operation, outcome counters,
and the observed ceiling (the speed at which degradation first occurred).
Over time this is the calibration record — the REAL throughput ceiling,
measured, not guessed.

## Scope

Research beats first. The pattern extends to any cycled operation with an
observable failure signal: gate, run, record outcome, let the AIMD ladder
find the ceiling. Do not add pre-set intervals to new drop-ins — add an
operation state and a detector.

---

Back to the [documentation index](../README.md).
