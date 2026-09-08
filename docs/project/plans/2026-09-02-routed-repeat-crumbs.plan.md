<!-- plan: status=executed risk=normal accepted=2026-09-02T13:01:23Z routed-from=repeat-crumbs -->
# 2026-09-02 — routed candidate

Routed by scripts/router-tick.py from alert identity `repeat-crumbs`
at 2026-09-02T13:00:45Z. Alert text: [oversight] repeat-crumbs: identical breadcrumb loop detected

## Steps

- [x] Investigate the alert, fix or park, with a named verification
      Verification: `make test` green in the owning repo

      Investigated 2026-09-08: false positive, detector deleted.
      `probe_repeated_breadcrumbs` compared the last two STATE.md lines
      for byte-identity including timestamps — only reachable via
      same-second concurrent duplicates (2026-09-02T13:00:43Z: two cadence
      jobs both wrote `sources | breaking | fetch FAILED http=200`,
      detail-less row from lib/sources.sh:148), never a loop. A real
      stuck loop spans minutes → timestamps differ → probe blind to its
      actual target. One firing in 119k rows; alert row 6dac8e59 archived
      2026-09-05. Repeat-condition spam already handled by ledger
      identity/window BUMP dedup + SUPPRESS_MIN; loop recognition over
      time lives in the steer leg. Fix: hngh-automation ca34ce6 (probe +
      call site deleted, 8 lines). `make test` in hngh-automation green
      (rc=0) pre-commit; live event-mode tick rc=0.
