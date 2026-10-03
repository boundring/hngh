<!-- plan: status=executed risk=normal accepted=2026-09-18T01:41:57Z routed-from=feedback-df606ea1 -->
# 2026-09-14 — routed candidate

Routed by scripts/router-tick.py from alert identity `feedback-df606ea1`
at 2026-09-14T01:00:39Z. Alert text: [feedback:correction] Logs · reports & digest: When we clicked 'Mark read' on one report, all reports disappeared, replaced by 'no unread reports'. Seems like that's a broken feature, it's marking all reports as read with any one of many buttons for each one.

## Steps

- [x] Delve: opened research subject fail-20260914-feedback-df606ea1 (appended automation/research-subjects.txt 2026-10-03); disposition recorded as killed in automation/research-dispositions.tsv -- third queue occurrence of the identical operator prose already dispositioned via correction-3146c023 (x76) and correction-5dfa8329 (x2): stale dashboard process predated the mark-read endpoint, 404s swallowed by .catch; resolved by restart 2026-09-14T00:13Z, first success 00:28:42Z cursor b5b83d3c, inline surfacing fix + operator dismiss 2026-09-14T22:43:22Z. Alert fixed (durable fix landed via 3146c023; live read cursor still advancing 2026-10-03).
      Verification: research subject fail-20260914-feedback-df606ea1 present in research-subjects.txt with a recorded disposition; alert fixed or parked -- SATISFIED 2026-10-03 (disposition row: automation/research-dispositions.tsv last row; research doc: docs/research/2026-10-03-fail-20260914-feedback-df606ea1.md).
