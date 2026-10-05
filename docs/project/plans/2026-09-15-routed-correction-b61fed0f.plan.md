<!-- plan: status=executed risk=normal accepted=2026-09-18T01:41:57Z routed-from=correction-b61fed0f -->
# 2026-09-15 — routed candidate

Routed by scripts/router-tick.py from alert identity `correction-b61fed0f`
at 2026-09-15T10:00:39Z. Alert text: correction b61fed0f: no named check found (Scrolling seems to be broken, both sides.) ×2

## Steps

- [x] Delve: open research subject fail-20260915-correction-b61fed0f for correction-b61fed0f; record disposition; then fix or park
      Verification: research subject fail-20260915-correction-b61fed0f present in research-subjects.txt with a recorded disposition; alert fixed or parked
      -> killed (fixed): duplicate re-route of the 09-12-fixed defect; fix landed 2026-09-14T12:14Z (commit 8934e320 on main: .sv{grid-template-rows:minmax(0,1fr)} in dashboard/sessions-view.js, failing-first test test_sv_row_bounded_so_both_panes_scroll in tests/test-dashboard-p1-ui.py); occurrences 2026-09-15T11:00/12:00Z are dedup-expired replays of the open queue row (identical text, none after 2026-09-15T12:00:39Z), not fresh breakage; subject fail-20260915-correction-b61fed0f appended to research-subjects.txt (line 519) with killed disposition in research-dispositions.tsv; fix re-verified on the 2026-10-05T20:07Z wake (constraint at sessions-view.js:132, 8934e320 ancestor of HEAD, automation make test rc=0)
      Verification: research subject fail-20260915-correction-b61fed0f present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Occurrences

- 2026-09-15T11:00:39Z re-occurred (dedup window expired)
- 2026-09-15T12:00:39Z re-occurred (dedup window expired)
