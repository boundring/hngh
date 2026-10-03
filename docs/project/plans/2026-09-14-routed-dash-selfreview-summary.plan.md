<!-- plan: status=executed risk=normal accepted=2026-09-18T01:41:57Z routed-from=dash-selfreview:summary -->
# 2026-09-14 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:summary`
at 2026-09-14T00:00:40Z. Alert text: [dash-selfreview] summary: 1 findings (1 unacceptable-now, 0 acceptable-for-now)

## Steps

- [x] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
      CLOSED 2026-10-03T21:35Z — re-anchored first on the newest tick
      (2026-10-03T17:00:10Z-alert-f438818b.md + -d7de0902.md, occurrences
      through 21:11:41Z): sole unacceptable-now child still served:index.html
      marker 'verdict-pill' absent. Dream sanity checks killed the red herring:
      source grep -c verdict-pill dashboard/index.html = 0 AND served body = 0
      (HTTP 200), so the file body mirrors the served body — the served-stale/
      cache hypothesis is false at the source. Live reproduction before any
      edit: python3 -B jobs/dashboard-self-review.py printed the finding
      (plus 2 transient feed-fresh rows, unrelated live-producer state).
      History anchor: f7e73c69 turned index.html into the newspaper front
      page and moved the verdict pills to console.html (at that commit:
      index.html 0 markers, console.html 1) — the PAGE_MARKERS entry is the
      stale side, never the page. Fix, one side only per the 2026-10-03
      dashboard deficiency slice brief:
      jobs/dashboard-self-review.py PAGE_MARKERS "index.html" repointed
      verdict-pill -> mast-splash (marker the front page actually carries,
      dashboard/index.html:19); coverage retained as a new
      "console.html": "verdict-pill" entry (console.html:14 carries it,
      served HTTP 200). New failing-first regression test
      tests/test-dashboard-selfreview-page-markers.py (RC=1 pre-edit naming
      the exact stale pair, OK post-edit) + one Makefile test-block line.
      Named verifications: python3 -B jobs/dashboard-self-review.py prints
      nothing post-fix (0 findings, silent all-clear by design), run twice;
      make test (automation full gate) green, GATE_RC=0. Not touched: the
      four older dash-selfreview summary plan slugs (expiry governs them),
      the expired sibling served:index.html candidates, the page files,
      and unrelated working-tree edits. Session 2026-10-03T21:0xZ opencode
      run, model opencode-go/glm-5.3-flash.
