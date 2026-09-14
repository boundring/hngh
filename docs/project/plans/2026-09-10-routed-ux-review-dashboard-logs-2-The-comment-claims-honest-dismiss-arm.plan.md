<!-- plan: status=executed risk=normal accepted=2026-09-10T04:31:26Z routed-from=ux-review:dashboard-logs:2-The-comment-claims-honest-dismiss-arm -->
# 2026-09-10 — routed candidate

Routed by scripts/router-tick.py from alert identity `ux-review:dashboard-logs:2-The-comment-claims-honest-dismiss-arm`
at 2026-09-10T04:00:18Z. Alert text: 2. The comment claims "honest dismiss... arm first", but the code only arms for items in the `live` list (not dismissed), yet `armedId` persists across renders without clearing on tab switch or new data fetch, allowing stale confirm buttons to appear on unrelated items -> violates "concrete nouns" by describing a state that doesn't match the actual DOM lifecycle -> `hngh-automation.js`. fix or park with cause

## Steps

- [x] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Execution (2026-09-14)

FIXED (not parked). The monolith file named in the alert (hngh-automation.js)
no longer exists — the finding's code now lives in automation/dashboard/app.js
(armedId declared :165, honest-dismiss comment :186-188, render guard
`armedId === it.id` :189). The cross-item stale-confirm clause is impossible by
construction: the confirm renders only where armedId matches the item id inside
the shown list. Real defect: the arm persisted across data fetches, so a
recurring item re-emitted under the same id (or one dismissed elsewhere) could
come back with a stale armed confirm. Fix: stale-arm revalidation inside
fetchOpState (the data boundary) — the arm survives a fetch only while its item
is still live under the render's own predicate (present and not dismissed), and
clears otherwise; not cleared unconditionally on fetch, so polls cannot kill the
two-click confirm mid-flow. Tab switches carry no new data and keep the arm.
Contract pinned in automation/tests/test-dashboard-p0.py (HonestDismiss,
src() convention since dashboard machine data is gitignored for new files).
Disposition row: automation/docs/BACKLOG.md "Findings disposition pass 2".
Named verification: automation `make test` ALL PASS (baseline green pre-edit,
re-run post-edit); new p0 suite 13/13 OK. Commit 68f0a03 pushed to origin.
