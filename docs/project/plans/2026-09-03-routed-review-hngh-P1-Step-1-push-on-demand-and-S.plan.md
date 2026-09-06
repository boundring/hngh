<!-- plan: status=accepted risk=normal accepted=2026-09-03T11:01:24Z routed-from=review:hngh:P1-Step-1-push-on-demand-and-S -->
# 2026-09-03 — routed candidate

Routed by scripts/router-tick.py from alert identity `review:hngh:P1-Step-1-push-on-demand-and-S`
at 2026-09-03T10:00:45Z. Alert text: review P0/P1 (hngh): P1: Step 1 (push-on-demand) and Step 3 (email digest) rely on `scripts/report-queue` for alerting, but the autonomy rule/grounding notes do not confirm this script exists in `hngh`; if missing, the "park with an alert row" verification fails.

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
