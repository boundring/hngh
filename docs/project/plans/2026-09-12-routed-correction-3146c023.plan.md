<!-- plan: status=executed risk=normal accepted=2026-09-12T20:32:27Z routed-from=correction-3146c023 -->
# 2026-09-12 — routed candidate

Routed by scripts/router-tick.py from alert identity `correction-3146c023`
at 2026-09-12T20:00:35Z. Alert text: correction 3146c023: no named check found (Clicking "mark read" appears to do nothing for reports.) ×2

## Steps

- [x] Delve: open research subject fail-20260912-correction-3146c023 for correction-3146c023; record disposition; then fix or park
      Verification: research subject fail-20260912-correction-3146c023 present in research-subjects.txt with a recorded disposition; alert fixed or parked
      Outcome (2026-09-14T11:15Z): killed -- live dashboard process predated
      the mark-read endpoint (9b0876c, 2026-09-11T20:09Z; no restart until
      2026-09-14T00:13Z), POSTs 404ed and the UI swallowed every non-403
      failure (76 invisible clicks). Acute: resolved by the restart (first
      success 00:28:42Z, cursor b5b83d3c). Durable: mark-read failures now
      surface inline in the queue header (automation free commit, pinned in
      tests/test-dashboard-p1-ui.py). Disposition row in
      automation research-dispositions.tsv; cursor semantics -> sibling plan
      2026-09-14-routed-correction-5dfa8329.
