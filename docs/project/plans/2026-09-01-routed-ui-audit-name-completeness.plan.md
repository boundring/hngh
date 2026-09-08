<!-- plan: status=executed risk=normal accepted=2026-09-01T02:01:23Z routed-from=ui-audit:name-completeness -->
# 2026-09-01 — routed candidate

Routed by scripts/router-tick.py from alert identity `ui-audit:name-completeness`
at 2026-09-01T01:00:13Z. Alert text: ui-audit name-completeness: 3 violation(s) — router-rearm-precheck ¦ publication-lines-contract ¦ ebook-book-inputs

## Steps

- [x] Investigate the alert, fix or park, with a named verification
      Verification: `make test` green in the owning repo
      Executed 2026-09-08T00:08Z (this wake): investigated and FIXED —
      all three violations (router-rearm-precheck ¦
      publication-lines-contract ¦ ebook-book-inputs) were phantom rows.
      Root cause: the name-completeness rule fetched schedule.json
      node-side while the corpus came from the rendered page — two
      clocks; a 30m schedule-feed regen landing between the page's
      fetch and the audit's read files names the page has not fetched
      yet. Every historical firing matches the one-shot
      first-tick-after-feed-change shape (2026-08-29/09-01/09-02 12:00
      queue refreshes; 2026-09-06 21:00 drop-ins) — zero violations on
      every stable-feed run (telemetry events table). Fix,
      hngh-automation f9723c3 (owning repo): the feed is fetched inside
      the page and the corpus measured in the same evaluate — one
      instant, no skew window; on a miss, ScheduleView refresh +
      settle, re-measured once before filing. Evidence: zero
      name-completeness rows in STATE.md from the fix landing
      2026-09-07T08:19:16Z through 2026-09-08T00:01Z (16 hourly
      ui-audit mounts, all clean). Verify (met): automation `make
      test` green rc=0 at 2026-09-08T00:07Z — after fixture fix
      hngh-automation 6b9ca00 (the committed test placed its FAKE_DOW
      date stub after the seed section, so the Monday-gated lessons
      seed saw the real weekday and the suite was Monday-only; 45/45
      on a real Tuesday post-fix). The 2026-09-06 parked duplicate's
      operator escalation ("re-occurred 3 times without landing") is
      discharged by this landing; the two 09-02/09-03 re-route
      duplicates of the same identity ticked in the same ceremony.
