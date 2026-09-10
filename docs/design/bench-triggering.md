# Bench triggering — occasional, event-driven, never nightly

Status: DESIGN - operator directive 2026-09-10. Companion to
[meta-patterns.md](meta-patterns.md) (rehearsal-before-act, honest-state)
and the demotion machinery (automation/lib/model-demote.sh, landed as
eb8c242).

> A benchmark is a measurement taken to make a decision. When there is
> no decision pending, measuring is only expense wearing a lab coat.

## What exists today

- `automation/jobs/model-bench.sh`: three deterministic probes per
  model, one JSON line per model into `stats/model-bench-<date>.jsonl`
  plus a digest `digest/BENCH-<date>.md`. The model list is the
  `BENCH_MODELS` var from `config.env` (common.sh sources it) - there
  is no fleet discovery: `unsloth_chat` addresses models by explicit
  name, so the fleet IS the config list, edited by the operator or a
  certified session.
- `hngh-model-bench.timer` fires it nightly at 01:10Z;
  `cadence/day/10-bench-fresh.sh` re-runs the whole fleet when no
  result is <24h old. Both are schedule-driven: cost lands nightly
  whether or not any ranking decision is pending.
- `cadence-params.tsv` already carries the operator directive as
  `benchmarking-backburner=1` (documentation-only row).
- `automation/lib/model-demote.sh` tracks consecutive bad-execution
  outcomes per model; a demoted model is skipped by select_model until
  an ok outcome clears it.

## The two triggers

### 1. New-model trigger (week tier, cheap diff)

A weekly probe (drop-in in `cadence/week/`, the existing tier) diffs
the current `BENCH_MODELS` list (plus `UNSLOTH_FALLBACK_MODELS`) against
the models present in the newest `digest/BENCH-*.md` / the
`stats/model-bench-*.jsonl` history. An unbenched name is a new model
worth ranking: run `model-bench.sh` scoped to just that model
(BENCH_MODELS is already parametrizable - invoke with
`BENCH_MODELS=<new-model>` in the environment; the script needs no
changes for this) and file an operator-item with the ranking delta
(score vs the current top, from the digest).

Discovery is honest about its limit: the machine cannot see a fleet
the config does not name. The weekly probe is therefore a diff, not a
scan - the new-model trigger fires when the tracked list changes, not
when an arbitrary server gains a model.

### 2. Recalibration trigger (drift, not novelty)

Monthly (a cadence-params row, `benchmark-recalibrate-days`, default
30), re-bench exactly two models: the CURRENT top model (drift check -
the "enough time/development has passed" clause) and any demoted model
that has not been cleared (a demotion evidence re-check: if the model
now scores, the demotion was ambient; if it fails again, the demotion
stands with fresh proof). Re-testing the full fleet needs an important
reason - operator ask or the new-model trigger - and never happens on
a schedule.

### Integration

- Demotion: a demoted model is never re-benched by the recalibration
  trigger EXCEPT as the demotion-evidence case above; the trigger
  passes its result to `record_model_outcome` when it does (an ok
  clears the demotion; another bad-execution reinforces it).
- Quiet window: the bench loads the host (five model loads per run);
  it never runs while delegated sessions are compiling. The trigger
  checks the failfirst development state first (speed active + no
  running session in budget.md within the last 30 minutes) and
  defers otherwise - a THROTTLE'd or busy host defers the bench, not
  the reverse.
- Operator-item, not silent ranking: every trigger firing files an
  operator-item (doctrine section 4) with the delta, because a ranking
  that changes the active model is an operator-visible decision.

## Retirement of the nightly timer

`hngh-model-bench.timer` (daily 01:10Z) and the `10-bench-fresh`
catch-up (which re-runs the full fleet whenever the result ages past
24h - the exact always-on behavior this design retires) get routed as
plan steps: the queue executes, the director executes the
operator-authorized systemd disable. No machine session touches unit
lifecycle directly.
