<!-- plan: status=expired risk=normal accepted=2026-09-18T01:41:57Z routed-from=dash-selfreview:summary  cause=obsolete disposed=2026-09-20T13:15:51Z reason=fix already landed via executed siblings 2026-09-12-routed-dash-selfreview-ledger-sanity and 2026-09-12-routed-dash-selfreview-ledger-sync-skew (66b67cf4, 5f876e0a, c0c0bd55); own check verified silent 2026-09-20T13:10Z (drift 44<=50) -->
# 2026-09-13 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:summary`
at 2026-09-13T03:00:49Z. Alert text: [dash-selfreview] summary: 1 findings (1 unacceptable-now, 0 acceptable-for-now) ×5

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-20T13:15Z disposition examined read-only (session
  2026-09-13-routed-dash-selfreview-summary overnight beat, brickertop;
  dream brief 2026-09-20T13:04Z). The routed finding is already fixed
  by two executed sibling plans — no new code cut here. Measured:
  - Fix landed: 66b67cf4 (skew-aware ledger-sanity check,
    LEDGER_SKEW_MAX_AGE tree-freshness guard), 5f876e0a (hourly ledger
    sync + orphan reconcile), c0c0bd55 (48h-prune body deletions);
    sibling plans 2026-09-12-routed-dash-selfreview-ledger-sanity and
    2026-09-12-routed-dash-selfreview-ledger-sync-skew both carry
    status=executed with the fix history.
  - The finding's own check is silent on this tree (verified
    read-only, no dashboard-self-review.py run): scripts/report-queue
    --json summary kinds 3970+41+17+160=4188 rows vs 4232
    docs/project/report-bodies/*.md -> drift 44 <= LEDGER_DRIFT_MAX 50
    (2026-09-20T13:10Z); HEAD age 3975s — fresh tree, skew guard armed
    either way (dashboard-self-review.py:48-49,160-211).
  - Hermetic skew test green in this pass:
    tests/test-dashboard-selfreview-ledger-skew.py 6 tests OK; wired
    at automation/Makefile:84.
  - No ledger-sanity dash-selfreview rows in the live ledger since
    2026-09-16; the only 09-18/09-19 dash-selfreview rows are
    feed-fresh identities (different checks, own routed plans).
  - BLOCKER recorded per autonomy rule: automation `make test` red at
    tests/test-manga-draft.py TestShelloutContract (3 failures,
    shell-out canaries interpolated) — all 151 lines of that test
    class are UNCOMMITTED working-tree additions from an in-flight
    session's slice (git diff vs HEAD is pure insertion; file dirty);
    committed code carries no failing test; unrelated to this finding
    (different job, different identity). Recorded, not fixed.
    Suites before it in the target passed; suites after it never ran.
  Plan disposed parked (cause=obsolete): the finding's fix and
  verification live in the sibling plans; this routed duplicate has
  nothing left to execute.
