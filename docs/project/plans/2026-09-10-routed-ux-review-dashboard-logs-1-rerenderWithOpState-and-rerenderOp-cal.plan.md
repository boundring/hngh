<!-- plan: status=proposed risk=normal accepted=- routed-from=ux-review:dashboard-logs:1-rerenderWithOpState-and-rerenderOp-cal -->
# 2026-09-10 — routed candidate

Routed by scripts/router-tick.py from alert identity `ux-review:dashboard-logs:1-rerenderWithOpState-and-rerenderOp-cal`
at 2026-09-10T04:00:18Z. Alert text: 1. `rerenderWithOpState` and `rerenderOp` call `renderLogs` without checking if `lastRender.res` is defined, causing a runtime error when operator state updates before the initial spine load completes -> violates "evidence-first" by crashing the UI instead of rendering a known empty or loading state -> `hngh-automation.js`. fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
