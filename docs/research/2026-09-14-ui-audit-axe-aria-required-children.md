# 2026-09-14 — ui-audit axe:aria-required-children on #tabs

## Question

Why does the ui-audit axe scan report `aria-required-children` on `#tabs`
(role=tablist) when the static HTML carries nine `role="tab"` children, which
element is the disallowed child, and what disposition (fix or park) closes the
alert that re-occurred across 2026-09-11..09-14 (identities
fail-20260911..fail-20260914-ui-audit-axe-aria-required-children)?

## Evidence read

- Alert identity `ui-audit:axe:aria-required-children`, text "1 violation(s) —
  #tabs", filed by `automation/jobs/ui-audit.mjs:70-76` (full-page axe-core
  scan against the served dashboard at 127.0.0.1:8890).
- Static source is clean: `automation/dashboard/index.html:31-41` — `#tabs`
  role=tablist with nine `role="tab"` buttons. So the violation is runtime-only.
- One-shot puppeteer+axe repro mirroring the audit's page setup (networkidle2,
  click `#tab-schedule`, settle) reproduced it: `#tabs` had childCount=10 —
  nine `BUTTON[tab]` plus one `BUTTON[null]`; axe failureSummary pinned the
  cause exactly: "Element has children which are not allowed: button[aria-label]".
- The disallowed child is the feedback pip: `automation/dashboard/feedback-view.js`
  `injectPips()` appended the `.fb-pip` button (implicit button role,
  aria-label "send feedback about tab bar") directly into `#tabs` (pre-fix
  line 43). A tablist may own only `role=tab` children — axe is right.
- Why four days of re-routes never landed: the violation exists only after JS
  runs, so any static-source inspection looks clean, and no prior session ran
  the axe surface itself.

## Doctrine applied

- Verify on the step's own surface: reproduced with the audit's own toolchain
  (puppeteer-core + axe-core/axe.min.js, same viewport and settle waits)
  instead of arguing from source.
- Failing test first: `automation/tests/test-dashboard-p1-ui.py`
  `FeedbackPipPlacement.test_tab_bar_pip_never_inside_tablist` — red before
  the fix, green after (textual contract, the tracked regression surface for
  the dashboard wave).
- Fail-closed scope discipline: the sibling `axe:color-contrast` identity
  (.gbar-lab yellow-on-green) is a different routed plan — untouched here.

## Findings

- Root cause: runtime DOM injection of a non-tab child into a role=tablist
  (`feedback-view.js` injectPips), not a static-markup defect.
- Fix (landed in the automation slice, 2026-09-14): the pip now mounts on the
  nav wrapper around the tablist (`tabs.parentNode.appendChild`), and
  `automation/dashboard/style.css` adds
  `nav[aria-label="dashboard sections"]{display:flex;align-items:flex-end}`
  so the pip keeps its place on the strip baseline. Semantics stay honest:
  the pip is a button, not a tab.
- Verification: post-fix repro reports zero `aria-required-children` rows;
  automation `make test` green (rc=0, 2026-09-14T11Z).
- Process hazard recorded: the five automation files of this slice were
  staged for a free commit and were swept into a sibling session's commit
  4630885 (its plan tick + my files) — the staged-index hazard of lesson
  2026-09-14T08:44:40Z, observed from the victim side. Content verified
  intact in that commit; no amend (never amend a landed commit).

## Recommended next line

The next scheduled `cadence/hour/05-ui-audit.sh` tick is the standing
confirmation: zero `aria-required-children` rows expected; if the identity
re-fires, it re-routes with a fresh timestamp. The open `axe:color-contrast`
identity (`.gbar-lab` 1.45:1 yellow-on-green, `automation/dashboard` gantt
track labels) is the next axe debt worth its own delve.
