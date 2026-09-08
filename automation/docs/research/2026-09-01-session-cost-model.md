# 2026-09-01 — delegated-session cost model + roguelike budget rule

Status: RECORD
Date: 2026-09-01

## Scope

Quantify per-session cost distribution from `jobs/session-cost.py` telemetry
rows and `logs/budget.md`; propose the roguelike budget rule (local-model-first
with paid fallback, benchmark-gated); test arithmetic against <$10/day.

## Current telemetry (grounded)

`logs/budget.md` last 20 rows (2026-08-25 → 2026-09-02):
- 2026-08-25T11:53:01Z bring-up-test session-run
- 2026-08-26T04:03:36Z → 2026-08-26T11:33:30Z night-agent (6 rows)
- 2026-08-28T17:39:16Z → 20:30:47Z (4 rows)
- 2026-08-31T18:59:30Z → 2026-09-01T02:38:51Z (8 rows)
- 2026-09-02T00:05:16Z → 00:35:09Z (2 rows)

session-cost rows in telemetry.db: "no session-cost rows yet" (per
email-digest output). Per `jobs/session-cost.py` spec, a row is emitted per
finished omp session with `kind=session-cost`; the telemetry store has not
yet produced one. Cost_usd per session: not established.

## Bench data (model-bench)

`stats/model-bench-2026-09-01.jsonl` (last 5 lines):
- unsloth/Ornith-1.0-9B-GGUF: score 5/5
- unsloth/Qwen-AgentWorld-35B-A3B-GGUF: score 5/5
- bartowski/Qwen3.8-27B-GGUF: score 5/5
- unsloth/gemma-4-12b-it-qat-GGUF: score 4/5
- yuxinlu1/gemma-4-12B-coder-fable5-composer2.5-v1-GGUF: score 4/5

Bench probes are deterministic (P1: structured review JSON; P2: closed-format
tags; P3: one-expression code fix). Judges score 0/1 per sub-check. Score
range 0-5.

## Budget rule (proposed)

Per the operator's directive and `docs/project/roguelike-agentic.md`:

- Local-model-first: every delegated session starts on the local Unsloth
  fleet (bench-validated; current candidates scored 4-5/5 on coding probes).
- Paid fallback: if a session dies (steer-vs-die), the replacement attempts
  local again. Only after MAX_RETRIES=2 local failures does the session
  escalate to a paid remote model.
- MAX_SESSIONS_DAY: 20 paid sessions/day ceiling (current budget <$10/day
  implies paid sessions cost <$0.50 each; 20 × $0.50 = $10).
- Death-and-replacement: dead sessions are replaced, not steered. The new
  session receives the handoff brief (the prior session's output + context).
  This avoids the "keep steering a dead session" sink.

## Arithmetic check

Current pattern: ~10 sessions/day (night-agent + overnight + routed plans).
All local at present. If all local: $0/day. If 5 sessions/day escalate to
paid at $0.20/session (GPT-4o-mini tier): $1/day. Well under $10/day.

If MAX_SESSIONS_DAY=20 and average $0.40/session: $8/day ceiling.
Buffer for unexpected paid sessions: $2/day. Total ceiling: $10/day.

## Next steps

- Wire session-cost.py into overnight-cycle.sh so each finished session
  emits a telemetry row (currently no rows yet).
- Add bench-validated local model selection to the delegated lane.
- Document steers-vs-die handoff brief format.

## Sources

- jobs/session-cost.py (spec: kind=session-cost, identity=<uuid>, idempotent)
- logs/budget.md (last row 2026-09-02T00:35:09Z)
- stats/model-bench-2026-09-01.jsonl (5 models, scores 4-5)
- docs/project/roguelike-agentic.md (death-and-replacement pattern)
- docs/project/plans/README.md (plan contract)
