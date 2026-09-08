# 2026-09-01 — continuous local-model benchmark loop design

Status: DESIGN
Date: 2026-09-01

## Scope

Design the standing loop for continuous local-model benchmarking. What to
measure, cadence tier, thresholds for local-first vs paid fallback. Ground in
`jobs/model-bench.sh` probe/judge code and `stats/model-bench-<date>.jsonl`
line format.

## Current setup (grounded)

`jobs/model-bench.sh` runs three deterministic probes per model:
- P1: structured review JSON (rung-6 review-adapter shape) with two planted
  defects: `#+` reader macro misuse and empty-list division.
- P2: closed-format instruction discipline (tier tags, exact shape).
- P3: one-expression code correction (Common Lisp average function).

Judge output: one JSON line per model appended to
`stats/model-bench-<date>.jsonl`. Fields: `ts`, `model`, `p1_json`,
`p1_div0`, `p1_reader`, `p2_format`, `p3_fix`, `score` (sum 0-5).

Current bench models (from `lib/model.sh`): Unsloth fleet.

## Metrics to measure

1. **Probe pass rate** (score/5): primary quality signal.
2. **Tokens/sec**: throughput metric. `jobs/model-bench.sh` doesn't yet
   capture this; add via `time` wrapper or model server metrics.
3. **Task completion on plan steps**: secondary signal — does the model
   actually complete the task, or just pass probes?

## Cadence tier

Per `docs/project/backlog.md` cadence-continuum row: the standing loop runs
on cadence `hour`, not `day` (bench data is cheap to collect, valuable to
track). One bench run per hour per model.

## Adopt thresholds

- **Local-first**: score >= 4/5 on last 5 runs (80% pass rate).
- **Paid fallback**: score < 4/5 for 3 consecutive hours. Escalate to paid
  model for the next session.
- **Model retirement**: score < 3/5 for 24 hours. Remove from BENCH_MODELS.

## Next steps

- Add tokens/sec capture to `jobs/model-bench.sh` (time wrapper around
  `unsloth_chat`).
- Write `scripts/bench-rolling.py` to aggregate last N runs and compute
  rolling averages.
- Wire into `overnight-cycle.sh` for hourly execution.

## Sources

- jobs/model-bench.sh (3 probes, judge output format)
- stats/model-bench-2026-09-01.jsonl (5 models, 4-5/5 scores)
- lib/model.sh (BENCH_MODELS list)
- docs/project/backlog.md (cadence-continuum row)
- docs/design/ledger-and-records-spec.md (§3 telemetry emit)
