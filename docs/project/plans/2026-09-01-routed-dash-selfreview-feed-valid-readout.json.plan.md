<!-- plan: status=executed risk=normal accepted=2026-09-01T12:01:27Z routed-from=dash-selfreview:feed-valid:readout.json -->
# 2026-09-01 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:feed-valid:readout.json`
at 2026-09-01T12:00:47Z. Alert text: [dash-selfreview] feed-valid:readout.json: unacceptable-now — unparsable: Extra data: line 331 column 1 (char 7876)

## Steps

- [x] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
      Executed 2026-09-06T01:25Z (this wake — the cycle's delegated
      session for the step): root cause found and fixed in
      hngh-automation commit c129e61. The 2026-08-30 atomic-write fix
      (760adb5) gave both readout.json writers tmp+rename but a SHARED
      tmp path (dashboard/.readout.json.tmp). At the daily 11:30Z
      collision — the 30m tier's cadence/30m/05-readout.sh and the
      morning-report service's jobs/refresh-dashboard.sh ExecStartPost
      both run `scripts/dashboard-readout --json >shared-tmp` in the
      same second (STATE.md 2026-09-01T11:30:42Z/43Z) — writer A's mv
      renamed the shared tmp to readout.json while writer B's open fd
      still pointed at that inode; B's dump then landed INSIDE the live
      readout.json, leaving doc-B + doc-A-tail — exactly the alert's
      "unparsable: Extra data: line 331 column 1 (char 7876)" (7876 =
      B's complete doc; the tail is A's longer doc). B's failed mv
      logged the misleading "reader failed; leaving prior readout.json"
      (11:30:43Z row). The corrupt file sat until the next SOLO 30m run
      healed it at 12:00:43Z (generated=12:00:43-04:00 blob in the
      12:02Z sweep commit 0784c8f); sessions.json froze at 11:29:49Z
      for the same window because jobs/sessions-feed.py fail-closes on
      an unparsable readout — the twin feed-fresh finding. Fix:
      per-process tmp names (<target>.<pid>.tmp, shell $$ / python
      os.getpid()) across ALL feed writers (readout x2, sessions,
      operator-items, schedule, plan, kb, time-ledger) plus the
      in-place data.json write in update_dashboard (two same-second
      callers daily at 12:00Z) — rename can no longer break a sibling
      writer's fd indirection; names keep the *.tmp suffix so the
      gitignore still covers crash lingers. New
      tests/test-readout-writers.py pins the contract (fails on any
      regression to a shared/fixed tmp). Verify (met): the finding's
      own check passes — python3 jobs/dashboard-self-review.py exits 0,
      silent all-clear (feed-fresh/feed-valid/served/ledger zero
      findings), re-confirmed after a live fixed-writer run (readout
      regenerated, parses, spine keys timeline/queue/verdict present);
      automation `make test` green (bash -n, 11 test files incl. the new
      contract test, supervision selfcheck, identifier lint); hngh
      kernel `make test` green pre-ceremony (2855 checks).
