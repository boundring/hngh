<!-- plan: risk=normal accepted=2026-09-08T04:32:07Z routed-from=ui-audit:unavailable  cause=obsolete disposed=2026-09-09T19:11:58Z reason="ui-audit ran green end-to-end 2026-09-09: automation/node_modules present (puppeteer-core+axe-core), /usr/bin/google-chrome-stable default executablePath, exit 0 with 0 violations (operator-observed subagent run); audit "-->
# 2026-09-08 — routed candidate

Routed by scripts/router-tick.py from alert identity `ui-audit:unavailable`
at 2026-09-08T02:43:12Z. Alert text: ui-audit unavailable: Cannot find module 'axe-core/axe.min.js'

## Steps

- [ ] Delve: open research subject fail-20260908-ui-audit-unavailable for ui-audit:unavailable; record disposition; then fix or park
      Verification: research subject fail-20260908-ui-audit-unavailable present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Occurrences

- 2026-09-08T03:00:34Z re-occurred (dedup window expired)
