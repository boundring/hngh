# 2026-09-25 — P3c: gate refusals ride the spine

Refoundation plan R8/P3(c): every gate refusal that ends a session
unobserved now reports to the spine — one crumb plus one deduped report
row naming the cheaper tier it defers to.

## What landed (automation free tier)

- `automation/lib/breadcrumbs.sh` — new `gate_refusal() gate detail tier
  [lane=<id>]`: breadcrumb (job `gate`, event `gate-refusal`) plus
  `report-queue --add alert --identity gate-refusal:<gate> --window
  604800`. Silent and fail-open: pacers run inside command substitution
  where stdout is the `used cap` protocol, and reporting must never
  block a gate. `HNGH_REPORT_QUEUE` env override selects the queue path
  (hermetic tests).
- `automation/lib/model.sh` — `_pace_refused()` hooked at all nine
  blocked branches: `quota_pace_blocked` (hard+soft),
  `quota_pace_blocked_5h` (hard+soft), `quota_pace_blocked_window`
  (hard+soft), `quota_pace_blocked_week` (hard+soft),
  `gemini_burst_blocked` (hard only; it has no soft branch). Identity is
  `pace-<fn>`.
- `automation/ng/cadence.py` — `_gate_refusal()` mirroring the bash
  seam (crumb via `lib/crumbs.py`, row via `HNGH_REPORT_QUEUE`/root
  `scripts/report-queue`), wired at legs-exhausted (all model legs
  blocked → `cadence-legs`, defers to next beat window) and
  budget-exhausted (`cadence-budget`, spent/cap in the detail).
- `automation/jobs/cadence-tick.sh` — bailiff halt now adds the report
  row (`gate-refusal:bailiff`, defers to next tick); the crumb already
  existed inside `bailiff_check`.

## Deliberate trim

The plan's run-autonomous lane-picker boost (front-rank a lane named by
a pending gate-refusal row) was cut: no current gate site carries lane
context — model pacers, cadence legs, and the bailiff are not backlog
lanes — so the picker change would be inert plumbing on a ceremony-lane
file. The `lane=<id>` channel exists end-to-end on the reporting side
(it lands in the row body, greppable the same way
`last_increment_ts` reads lanes); the picker hook lands when a
lane-bearing gate appears.

## Bugs found while hooking

Two `apply_patch` hunks matched identical ` [ "$used" -ge "$cap" ] && {`
contexts in sibling pacer functions, cross-wiring the window/gemini
identities. Caught by the per-pacer identity assertions in the new
test; fixed and re-audited with an awk pairing check (2+2+2+2+1 hooks,
each naming its own function).

## Verification

- `automation/tests/test-gate-refusals.sh` (new, registered in
  `automation/Makefile`): stdout protocol stays exactly `used cap` with
  empty stderr under blockage; one report row per blocked pacer with
  the right identity and `--window 604800`; spine crumb lands in the
  sandbox journal; fail-open when the report queue is missing. 10/10
  ok.
- `_gate_refusal` smoke: both cadence rows and both crumbs written with
  overrides set (fake queue + sandbox db).
- `automation/ make test` (full gate) — see CHANGELOG entry.
