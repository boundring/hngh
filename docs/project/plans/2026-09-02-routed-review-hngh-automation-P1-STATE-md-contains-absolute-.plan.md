<!-- plan: status=accepted risk=normal accepted=2026-09-02T10:01:26Z routed-from=review:hngh-automation:P1-STATE-md-contains-absolute- -->
# 2026-09-02 — routed candidate

Routed by scripts/router-tick.py from alert identity `review:hngh-automation:P1-STATE-md-contains-absolute-`
at 2026-09-02T10:00:45Z. Alert text: review P0/P1 (hngh-automation): P1: `STATE.md` contains absolute home paths (e.g., `/home/bricker/Projects/etc/hngh-automation/...`) in the new log entries. This violates the "public-content gate" mentioned in the `hngh` lessons (`docs/project/lessons-2026-09-01.md` explicitly notes that absolute home paths are a gate violation and should be normalized to `~/` form).

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
