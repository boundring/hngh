# Value-add routing policy landed (2026-09-20)

Decision: docs/design/value-add-routing.md defines the cheap-model
routing policy table - task class -> executor, burst rules, per-call
token caps, daily guardrails, and the 6-slot zai concurrency retention.

Key commitments (all grounded in live params, no behavior change):

- Sustained T2 rides the zai glm-5.3-flash subscription leg, never
  Gemini; paid burst is a class property, and only coding completions
  (gemini-3.8-flash, 20 calls/3600s rolling) have it.
- Kimi K3's 40/day stays reserved for review transitions (ALWAYS-pin
  semantics already enforced in cadence/hour/33-research-beat.sh).
- Muse-spark-contributor is the sanctioned volume-judgment lane under
  the shared 200/day openrouter cap; muse full-1.3 stays the reserve.
- Z.AI concurrency retention: at most 6 in flight for swarm fan-out
  (operator directive 2026-09-15), route-pinned retries, workers 7-8
  wait or pin contributor Muse - no silent spill onto per-token cash.

This prices the cost-tiering taxonomy (docs/design/cost-tiering.md)
into the existing legs; automation/cadence-params.tsv and
automation/lib/model.sh already enforce every rung, so this is a
policy-statement slice, not a machinery slice.
