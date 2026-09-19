# Loop-cap patch proposal — collapse-guaranteed, upstream-ready (2026-09-19)

Target: `~/src/jcode/crates/jcode-app-core/src/tool/communicate.rs`.
Cap: `:1262 let max_loops = 200usize;`. Direct synthesis (plan full).

## Why forever-looping is already impossible (existing exits)

The loop already terminates on: empty plan (`item_count == 0`),
credential-failure waves (fail-fast with root-cause alert), no-more-
runnable (no active, no ready, no in-flight), all-terminal
(`terminal_count >= item_count`), plus the 200-loop error itself.
Recursion is bounded: `prefer_spawn` defaults fresh workers per node
(isolation over reuse), member-cap fallback frees finished workers,
then reuse-only, then stop-assigning. Stalls are flagged:
`transient_stall_loops` (5 max) for brief transitions, utilization
reports, progress cards per loop, wake-on-terminal.

The operator's point stands: the only missing guarantee is
collapse-to-finish UNDER the cap on large plans — the driver exits
at 200 with work remaining, not from danger but from a constant.

## Patch (minimal, collapse-preserving)

1. `CommunicateInput` struct (+1 field after `timeout_minutes`):
   `#[serde(default)] max_loops: Option<usize>,`
2. Driver init (`:1262`):
   `let max_loops = params.max_loops.unwrap_or(200).max(1);`
   (mirrors `timeout_minutes.unwrap_or(60).max(1)` at :1250 — same
   shape, same fail-safe floor, no unbounded zero.)
3. Tool schema: expose `max_loops` param on run_plan (description:
   "coordination loop budget; default 200; raise for large plans
   with collapse-verified families; the terminal/no-runnable/credential
   exits still bound every run").
4. No change to the error path, retention hint, cleanup, or gates.
   `plan::gate` still refuses pass over low-confidence siblings;
   blocked reports still trail at any budget.

## Steering hooks already present (foresight prepaid)

Progress cards per loop, `bg` status/output, wake on terminal,
assignment run-log, utilization report, low-confidence roster,
credential-wave broadcast. A raised budget stays observable through
all of them; the coordinator watches completed-ticking and
active-nonzero exactly as this session did for 7763s.

## Collapse guarantee statement

Raising the budget cannot expand forever: families close by synthesis
records (not node exhaustion), gates refuse pass at any budget, and
the terminal/no-runnable/credential exits fire regardless of
max_loops. The budget buys drain time, not growth room — growth
still requires explicit expand/inject calls, each gated.

## Recommendation

File upstream with this diff (option b from the sanity check):
exact file:line, 3-line change, default-preserving. Local patch
(option a) only if the maintainer is slow — it forks the runtime.
