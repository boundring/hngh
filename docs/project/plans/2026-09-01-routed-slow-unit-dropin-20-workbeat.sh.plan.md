<!-- plan: status=accepted risk=normal accepted=2026-09-01T02:01:23Z routed-from=slow-unit:dropin:20-workbeat.sh -->
# 2026-09-01 — routed candidate

Routed by scripts/router-tick.py from alert identity `slow-unit:dropin:20-workbeat.sh`
at 2026-09-01T01:00:13Z. Alert text: [oversight] slow-unit: dropin:20-workbeat.sh wall=657.7s median=150.0s ×44

## Steps

- [x] Investigate the alert, fix or park, with a named verification
      Verification: `make test` green in the owning repo
      Executed 2026-09-01T02:45Z (this wake — the cycle's delegated
      session for the step): investigated and FIXED — the alert is a
      false positive. The workbeat (cadence/hour/20-workbeat.sh ->
      scripts/overnight-cycle.sh) is bimodal by design: ~0.2s flock
      skip-exits, 150-240s bounded beats, and delegated sessions
      timeout-capped at TIMEOUT_S=1800 (`timeout "$TIMEOUT_S"` on the
      omp session). The routed alert wall=657.7s median=150.0s was an
      accepted-plan session working as designed;
      probe_time_ledger's 2x-median rule fired on every legitimate
      mode transition (44 false slow-unit rows 2026-08-27..09-01).
      Fix, hngh-automation 7caff48 (owning repo — commits free there):
      probe logic extracted to jobs/slow-units.py with a design
      ENVELOPE (dropin:20-workbeat.sh + hngh-overnight.service:
      cap 1800s + 60s kill-after/audit margin; over the envelope the
      median rule AND the envelope both still flag); 7 hermetic
      contract tests (tests/test-slow-units.py) wired into make test.
      Verify (met): automation `make test` green (bash -n all
      scripts, 21+7 tests, identifier lint); on the live
      dashboard/time-ledger.json the probe printed
      `dropin:20-workbeat.sh wall=797.2s median=18.0s` pre-fix and
      prints 0 rows post-fix — the false positive is gone, detection
      for every other unit unchanged.
