<!-- plan: status=parked risk=normal accepted=2026-09-25T18:03:49Z routed-from=crumbs-mirror:skipped  cause=obsolete disposed=2026-09-25T19:00:13Z reason=identity re-occurred 3 times without landing; operator escalation stands -->
# 2026-09-25 — routed candidate

Routed by scripts/router-tick.py from alert identity `crumbs-mirror:skipped`
at 2026-09-25T16:00:37Z. Alert text: crumbs mirror mismatch: crumbs rows=180023 watermark=21727520 skipped_total=95 importable=180023 spill=95 db=~/Projects/etc/hngh/automation/state/crumbs.db; verdict=mismatch:skipped evidence=skipped=95-spill=95

## Steps

- [ ] Delve: open research subject fail-20260925-crumbs-mirror-skipped for crumbs-mirror:skipped; record disposition; then fix or park
      Verification: research subject fail-20260925-crumbs-mirror-skipped present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Occurrences

- 2026-09-25T17:00:37Z re-occurred (dedup window expired)
- 2026-09-25T18:00:13Z re-occurred (dedup window expired)
- 2026-09-25T19:00:13Z re-occurred (dedup window expired)
