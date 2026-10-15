<!-- plan: status=executed risk=normal accepted=2026-09-18T01:41:57Z routed-from=ux-review:email-digest:defect-pace-stalling-0-steps-in-24h-3-pl -->
# 2026-09-16 — routed candidate

Routed by scripts/router-tick.py from alert identity `ux-review:email-digest:defect-pace-stalling-0-steps-in-24h-3-pl`
at 2026-09-16T10:00:39Z. Alert text: defect: "pace: stalling (0 steps in 24h; 3 plans pending)" uses hedging adjective ("stalling") instead of stating the literal fact -> violates writing register (cut hedging) and display register (one caption per state, no chatter) -> Progress section pace line fix or park with cause

## Steps

- [x] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
      Done 2026-10-15: pace() captions in automation/scripts/email-digest.py
      now lead with the literal delta ("pace: 0 steps in 24h; %d plans
      pending", "pace: %d steps in 24h"); rising/idle/first-digest branches
      stayed untouched (not named by the finding). Pinning tests rewritten
      red-first in automation/tests/test-queue-progress.py; automation
      `make test` green; real-repo compose renders the literal caption.

## Occurrences

- 2026-09-16T11:00:39Z re-occurred (dedup window expired)
- 2026-09-16T12:00:39Z re-occurred (dedup window expired)
