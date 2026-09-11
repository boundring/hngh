# 2026-09-11 — Post-hoc certification of the omp-bridge --propose/--plan-status change

## Scope

The 2026-09-09 integration plan (fully executed, 11/11 steps) landed
two commits directly on main: `a2f4d0e` ("feat: omp-bridge --propose
and --plan-status (plan step 3)") and `31768d2` ("fix: omp-bridge
--plan-status accepts bare slug or date-prefixed stem"). Both modified
the kernel script `scripts/omp-bridge`, making them code-surface
commits under the loop-history guard, and neither carried a candidate
label. The guard caught both; `make test` went red 2026-09-09..09-11
(rc=2), blocking kernel plan acceptance (overnight:plan-accept-gate
alert identity) and origin push.

## Decision

Pushed-or-shared history is never rewritten. The cure mirrors the
2026-09-06 generate-publication precedent (decisions.md 2026-09-06),
minimized to one candidate:

1. **Declared, not rewritten.** `KNOWN_EXEMPTIONS` in
   tests/scripts/test-loop-history-guard.py lists `a2f4d0e` and
   `31768d2` with reasons. The rule for future commits is untouched.
2. **Cured through the loop.** The candidate commit carrying this
   record binds the final `scripts/omp-bridge` content (per-file
   sha256 evidence, including the previously unbound --propose and
   --plan-status surfaces) — no revert/re-apply dance, because unlike
   526cd3f the content is already final and a no-op re-apply cannot
   form a commit; the certification binds what ships, and the guard
   covers the history.

## Evidence

- Loop-history guard before the cure: 2 violations (`31768d2`,
  `a2f4d0e`), exit 1 in `make test`.
- This candidate ran the standing ceremony surface end to end
  (create-run -> admit-transport -> propose -> issue-cert ->
  mutation-check) against real repository evidence; `make test` green
  after the cure.
