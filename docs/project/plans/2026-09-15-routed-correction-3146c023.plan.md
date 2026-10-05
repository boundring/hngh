<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z routed-from=correction-3146c023 -->
# 2026-09-15 — routed candidate

Routed by scripts/router-tick.py from alert identity `correction-3146c023`
at 2026-09-15T10:00:39Z. Alert text: correction 3146c023: no named check found (Clicking "mark read" appears to do nothing for reports.) ×2

## Steps

- [x] Delve: open research subject fail-20260915-correction-3146c023 for correction-3146c023; record disposition; then fix or park
      Verification: research subject fail-20260915-correction-3146c023 present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Occurrences

- 2026-09-15T11:00:39Z re-occurred (dedup window expired)
- 2026-09-15T12:00:39Z re-occurred (dedup window expired)
- 2026-10-05T15:06:28Z wake run-2 executed the step (run-1 log 20261005T110629 died early)

## Resolution

Killed as a duplicate identity, 2026-10-05: the plan's subject id
`fail-20260915-correction-3146c023` did not exist — the alert identity
correction-3146c023 was opened as research subject
`fail-20260912-correction-3146c023` (research-subjects.txt) and is
dispositioned killed at research-dispositions.tsv:107 (stale dashboard
process predated the mark-read endpoint 9b0876c; restart
2026-09-14T00:13Z resolved the acute case; durable inline error-surface
fix landed and is pinned in tests/test-dashboard-p1.py +
tests/test-dashboard-p1-ui.py MarkRead classes, both green on this
wake). The duplicate-prose identities 5dfa8329 and df606ea1 were
already killed citing :107 (:429, :435); following that precedent the
re-routed identity now has its subject row + killed-dup disposition
(research-dispositions.tsv), so the plan verification is satisfied
literally. No code change owed; the alert is quiet (no open queue row,
no occurrence since 2026-09-15T12:00Z).
