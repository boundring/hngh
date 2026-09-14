<!-- plan: status=executed risk=normal accepted=2026-09-10T04:31:26Z routed-from=ux-review:dashboard-logs:1-rerenderWithOpState-and-rerenderOp-cal -->
# 2026-09-10 — routed candidate

Routed by scripts/router-tick.py from alert identity `ux-review:dashboard-logs:1-rerenderWithOpState-and-rerenderOp-cal`
at 2026-09-10T04:00:18Z. Alert text: 1. `rerenderWithOpState` and `rerenderOp` call `renderLogs` without checking if `lastRender.res` is defined, causing a runtime error when operator state updates before the initial spine load completes -> violates "evidence-first" by crashing the UI instead of rendering a known empty or loading state -> `hngh-automation.js`. fix or park with cause

## Steps

- [x] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Execution (2026-09-14)

PARKED with cause (the finding offers fix-or-park). The named monolith
hngh-automation.js no longer exists — the code lives in
automation/dashboard/app.js. The claimed crash is unreachable in the served
sources: both rerenderWithOpState (:153) and rerenderOp (:161) early-return
on `lastRender.d === undefined` before any render call — the pre-load
window the finding describes routes to the known empty state, which is
exactly what the finding asks for; `lastRender.d` and `.res` are assigned
atomically in renderLogs (:601), so no state has d defined with res
undefined; the renderLogs chain (operatorItemsHtml/renderReports/
renderDigest/logsSum) consumes no `res`; the sole res consumer
renderHeader is call-site guarded (:155). A literal res check before
renderLogs would skip the op-items re-render these functions exist for —
harmful, not fixing. The finding's own check (op-state update before the
initial spine load does not crash) passes. Contract pinned in
automation/tests/test-dashboard-p0.py (OpRerenderPreloadSafety).
Disposition row: automation/docs/BACKLOG.md "Findings disposition pass 2".
Named verification: automation `make test` ALL PASS; new p0 suite 14/14 OK.
Commit 5cf1bf8 pushed to origin.
