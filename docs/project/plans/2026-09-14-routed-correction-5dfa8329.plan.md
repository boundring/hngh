<!-- plan: status=executed risk=normal accepted=2026-09-18T01:41:57Z routed-from=correction-5dfa8329 -->
# 2026-09-14 — routed candidate

Routed by scripts/router-tick.py from alert identity `correction-5dfa8329`
at 2026-09-14T02:00:20Z. Alert text: correction 5dfa8329: no named check found (When we clicked 'Mark read' on one report, all reports disappeared, replaced by 'no unread reports'. Seems like that's a) ×2

## Steps

- [x] Delve: opened research subject fail-20260914-correction-5dfa8329 (appended automation/research-subjects.txt 2026-10-03); disposition recorded as killed in automation/research-dispositions.tsv -- stale duplicate of correction-3146c023 (same mark-read pain: stale dashboard process predated the endpoint, 404s swallowed by .catch; resolved by restart 2026-09-14T00:13Z, first success 00:28:42Z cursor b5b83d3c, inline surfacing fix + operator dismiss 2026-09-14T22:43:22Z). Alert fixed (durable fix landed via 3146c023); beat-blockers residue already cleared.
      Verification: research subject fail-20260914-correction-5dfa8329 present in research-subjects.txt with a recorded disposition; alert fixed or parked -- SATISFIED 2026-10-03 (disposition row: automation/research-dispositions.tsv, last row).
