# 2026-09-09 -- budget-governance directive: operator-item on cap block, never unilateral cap amendments

Operator-directed 2026-09-09: "as few blockers and stalls as possible
today". Given in an omp session after the overnight session cap
exhausted before dawn and the machine spent the gap silently waiting
and burning filler instead of asking. This record is standing policy.

## The cap chain (cited)

Session spend is capped by a three-link chain
(automation/scripts/overnight-cycle.sh lines 43-47):

1. env `OVERNIGHT_MAX_SESSIONS_DAY` (operator-level override);
2. the Inventory row `sessions-day-max` in
   automation/cadence-params.tsv (line 34) -- operator-authorized; the
   row comment records its history: 8/day per operator authorization
   2026-09-07, since raised to 200 per operator authorization 2026-09-09
   ("open to crazy caps like 200");
3. legacy constant 4 (pre-Inventory behavior, unreachable while the
   row exists).

The ceiling is hard by design: the fail-first development tier tunes
concurrency WITHIN it, never the ceiling itself
(automation/scripts/overnight-cycle.sh lines 66-76;
automation/cadence-params.tsv rows failfirst-dev-concurrent-*).

## The exhaustion event

Under the 8/day authorization the chain exhausted at
2026-09-09T01:12:38Z: nine overnight sessions ran between
2026-09-09T00:00:16Z and 2026-09-09T01:12:38Z
(automation/logs/budget.md overnight rows for the day); the last is
agent-handoffs row 34 (automation/agent-handoffs.md,
2026-09-09T01:12:38Z). The cap-block path then took over
(automation/scripts/overnight-cycle.sh lines 71-75): it writes a
`budget-cap` breadcrumb and drops to the research-only beat -- no
operator-item, no surfaced decision request. The next overnight
session did not run until 2026-09-09T16:12:37Z (agent-handoffs row 35),
after the operator raised the cap midday. Roughly fifteen hours of
operator-priority stall on a day the operator asked for the opposite.

## The rule (standing)

1. When the session cap blocks an operator-priority plan,
   overnight-cycle files an operator-item requesting the cap amendment
   instead of silently waiting or burning filler. The filing surface is
   `operator_item()` in automation/lib/operator-item.sh: one alert row
   in the report-queue ledger (the contract) plus one `alert` crumb in
   STATE.md -- exactly what the operator-items consumer reads
   (automation/cadence/1m/05-operator-items.sh ->
   automation/jobs/operator-items-feed.py: crumbs whose event matches
   `alert` or whose text matches papercut | flagged | needs | operator
   decision). The filing path is demonstrated hermetically by
   automation/tests/test-cap-block-operator-item.py (seamed report root
   and state file; no real rows, no real cap change).
2. Spend caps are NEVER amended unilaterally by machine sessions. Only
   the operator amends the `sessions-day-max` row or sets the env
   override. Machine sessions request; the operator decides. The same
   boundary already holds for the development ceiling and every other
   money-adjacent knob.

Wiring note: the cap-block path in
automation/scripts/overnight-cycle.sh (lines 71-75) adopts
`operator_item()` as a follow-up; the helper and its proof exist first
so the call site lands as a one-line change with the surface already
green.

## Guardrails (unchanged)

No provider/credential key activation beyond recorded grants; no
systemd unit lifecycle changes; no edits to the cap chain's
authorization row by machine sessions; everything else governed as
documented in docs/design/autonomous-development-control.md and the
2026-09-09 operator flexibility doctrine
(docs/records/2026-09-09-operator-flexibility-doctrine.md).
