# Value-add routing policy - which cheap model buys what, and when paid burst is allowed

Status: POLICY - defined 2026-09-20 (value-policy node, light graph).
Companions: [cost-tiering.md](cost-tiering.md) (the T1/T2/T3 taxonomy this
policy prices), cadence-params.tsv (the live caps quoted below), and
`automation/lib/model.sh` (the chain that enforces the pins).

> Spend belongs where the thinking is. Every rung below the thinking is
> motion, and motion rides the subscription.

## The ladder in one line

Free local for mechanical -> subscription (Z.AI) for sustained bounded
intelligence -> contributor-priced Muse for judgment-adjacent volume ->
paid cash Gemini burst for coding completions only -> full Muse as
max-intelligence reserve -> operator session for the deciding step.

## Policy table

| Task class | Executor (first choice) | Burst allowed? | Per-call token cap | Daily / window guardrail |
|---|---|---|---|---|
| T1 mechanical: ledger appends, log parsing, renames, format fixes, telemetry, news articles | local unsloth chain (`MODEL_PIN=local`; news pins local per 2026-09-13 paid-cost conversion) | never - T1 never justifies paid spend | `MODEL_MAX_TOKENS` 1024 out (unsloth empty-retry exception 8192, model.sh:230) | free leg; bounded only by sessions-day-max 200 |
| T2 sustained bounded intelligence: swarm workers, plan-step sessions, worker fan-out, probes, defaults | zai glm-5.3-flash (`sustained-model` / `[agents].swarm_model`, 868k ctx) | no - sustained traffic stays on subscription, never Gemini | 1024 out per bounded call; sessions: loadout token-limit 50000, wall 1800s (launch-session.sh:118,235) | zai 300/5h rolling + 1500/week (Monday reset); concurrency 6 (below) |
| T2 research synthesis (33-research-beat) | every 2nd run pins zai glm-5.3 non-flash design leg (`kimi-research-share=2`, <=12/day); residual local pin shifts to zai by day, local reserved for the idle midnight window (hngh-wc4) | no - quota-paced rotation only | 1024 | shared zai bucket; research never blocks (pace-block falls through to local chain) |
| T2 review transitions (04-review-prep, terminal verdicts, digest) | kimi K3 `k3-256k`, ALWAYS pinned (`REVIEW=1 -> MODEL_PIN=kimi`) - the 40/day quota is conserved for exactly this | no | 1024, with reasoning-token headroom (budget >=64 even for trivial completions; thinking models spend reasoning inside max_tokens) | kimi-daily-cap 40/day, hard |
| T2 design feedback / coverage second opinions | muse-spark-1.3-contributor (`MODEL_PIN=feedback`, $0.10/$0.20 per 1M, 1,048,576 ctx); second pass swaps 1.2-contributor | allowed within the shared remote cap - this is the sanctioned "volume judgment" lane | 1024 | REMOTE_DAILY_CAP_CALLS 200/day (all openrouter pins share it) |
| Coding completions (whole files / patches, existing-code edits) | gemini-3.8-flash via `MODEL_PIN=remote` (`remote-model-coding`) - BURST-ONLY, never the default chain | yes - this is the only paid-burst class: 20 calls / rolling 3600s (`gemini-burst-max-calls` / `gemini-burst-window-s`) | 1024 | burst window cap + shared remote 200/day; sustained-model row forbids Gemini for sustained load |
| T3 deep intelligence: architecture, root-cause diagnosis, ceremony verdicts | operator session / certified strong model; no quota leg ever becomes the director | n/a | n/a | n/a - out of the cheap-model economy by definition |
| Max-intelligence reserve | muse full-1.3 | operator-triggered only; never in automatic rotation | - | - |
| Dead legs | opencode-go (caps 0 since 2026-09-19), lobehub (dropped 2026-09-11) | none - no revival without operator instruction | - | - |

## Burst models - the four rules

1. **Burst is a class, not a mood.** Only the coding-completions class
   has a burst lane (gemini-3.8-flash, 20 calls/3600s). Everything else
   degrades down the free chain instead of bursting upward.
2. **Sustained never bursts.** The `sustained-model` row pins sustained
   traffic to zai glm-5.3-flash explicitly "never gemini"; a demand
   spike on sustained work queues or waits, it does not re-route to
   per-token cash.
3. **Degradation order is fixed.** A pace-blocked or 429ing leg falls
   through inside `model_call` (research/reviews never block). Paid
   fallback for blocked T2 is muse-spark-contributor (cheap, capped) -
   never the gemini burst lane, which is entered only by its class pin.
4. **Operator steering outranks policy.** `OVERNIGHT_MODEL` and explicit
   `MODEL_PIN` env overrides are the operator, not a cost decision.

## Per-call token caps (summary)

- Bounded chain calls: 1024 out (`config.env:20`), all legs `--max-time` 300
  (leg-budgets.tsv, guard: tests/test-leg-budgets.py).
- Delegated sessions: loadout token-limit 50000, wall-clock 1800s.
- Context ceilings: zai glm-5.3-flash 868,928; muse 1,048,576; kimi 256k.
- Kimi thinking models bill reasoning inside max_tokens: pad small asks.

## Daily budget guardrails (summary)

- Delegated sessions: `sessions-day-max` 200/UTC day - hard ceiling;
  concurrency tunes within it, never above.
- Kimi: 40/day. Z.AI: 300/5h + 1500/week. OpenRouter pins (default,
  feedback, gemini): 200/day shared (`REMOTE_DAILY_CAP_CALLS`).
- Newspaper: 6 articles/day, local leg only, 1024 tokens each.
- Pacing reads each leg's tightest window (`quota_pace_blocked`); no
  leg is admitted without a declared time+output budget (no row, no
  chain admission).

## Concurrency 6 retention (operator directive 2026-09-15)

- Z.AI legs are shared with 6-slot concurrency: swarm fan-out against
  zai keeps at most 6 in flight - light fan-out, no saturation.
- The jcode harness ceiling (`[agents].swarm_max_concurrent_agents = 8`)
  stays, but zai-routed workers retain the 6-slot cap; workers 7-8 wait
  or pin muse-spark-contributor, they do not silently spill onto paid
  cash legs.
- Retries are route-pinned (same route re-attempt, spread by pacing) so
  a retry storm cannot convert subscription spend into per-token spend.

## Precedence and escape hatches

env override > explicit MODEL_PIN > task-class pin (this table) >
rotation shares (kimi-research-share, opencode-research-share) >
default chain (unsloth -> zai -> remote -> ollama -> deck -> kimi ->
ocgo -> archive-only) > archive-only.

## Evidence base

- Tiers: docs/design/cost-tiering.md (operator directive 2026-09-10;
  live split proof: glm-5.3-flash:high did T2/T3 shapes, qwen-flash did
  T1 cleanly, same day).
- Caps and pins: automation/cadence-params.tsv rows 22-44, 50, 55, 67;
  automation/config/leg-budgets.tsv; automation/lib/model.sh header.
- Rotation: automation/cadence/hour/33-research-beat.sh:685-762
  (kimi-review pin, zai design rotation, local-reserve window).
- Swarm defaults: ~/.jcode/config.toml [agents] (swarm_model
  zai:glm-5.3-flash, max agents 8) + cadence-params row 67 (6-slot
  zai concurrency, route-pinned retries, Muse clearance).
