# 2026-09-27 — Newspaper v2 rebuild

## Principle

A front page is read, not operated. v1 printed every article as a
collapsed disclosure bar — the paper read as the same console it
replaced. v2 doctrine: articles print OPEN with real body text, and
operator decisions are editorial cards whose choices show their
predicted outcome BEFORE the operator commits. This closes operator
feedback from 2026-09-27 ("practically the same dashboard as before";
decisions lack guidance, multi-choice, outcome previews, supporting
articles).

## Changes

- `automation/dashboard/newspaper-view.js` — rewritten (469 lines):
  - `article(kicker, headline, deck, bodyLines)` builds
    `details.open = true` (class `art`) — nothing hides behind a
    summary bar.
  - `decisionCard(kicker, headline, deck, bodyLines, choices)` — each
    choice is `{label, outcome, run(btnDone, progress)}`; the outcome
    text renders next to the button, visible before any click.
  - Flood family grouping: the 40 identical
    `[feedback:idea] from email` operator items collapse into ONE card
    ("The empty-idea flood (40 items)") with a root-cause body and two
    choices: Dismiss all (sequential `/operator-item/dismiss`, capped
    at 80, progress line) or Keep. Item text arrives
    alert_row-formatted (`job | kind | payload`), so the matcher is a
    needle search (`FLOOD_NEEDLE`), not an anchored regex.
  - Honest system sheet: an unresolved fleet-node name prints
    "mesh node (name unresolved)" plus the pending-fix note instead of
    a bare `?` (fleet-manager PascalCase fix is a separate kernel-lane
    slice).
  - Alerts sheet gains a status-glossary article (queued/done/acked).
- `automation/dashboard/style.css` — newspaper block replaced:
  Georgia masthead, double rules, small-caps dateline, beveled section
  banners, 2-column sheets with column rules, open articles with moss
  left borders, moss choice buttons with italic outcome previews,
  single-column fallback under 900px.
- `automation/dashboard-server.py` — `end_headers` now always sends
  `Cache-Control: no-store` (was `no-cache` on .css/.js/.json only;
  html responses carried no header, so the operator's browser served a
  stale front page).
- `automation/tests/test-dashboard-p1.py` — root-cause fix for the
  blank-feedback flood itself: `setUp` now seams `ds.FEEDBACK` to the
  sandbox (the missing line sibling test-dashboard-feedback.py already
  had). One `test_feedback_form_field_token` capture per `make test`
  run since 09-11 had been writing into the LIVE
  `automation/dashboard/feedback/` spool; 54-feedback-ingest drained
  them into the 40 identical open operator items. No live spool writes
  after the fix.
- `automation/tests/test-newspaper-view.py` — `NewspaperV2` contract
  class: articles print open; decision cards carry outcomes before
  click; flood is one card; honest system naming; v2 styles present.
  17/17.

## Verification

- `python3 tests/test-newspaper-view.py` 17/17 OK;
  `python3 tests/test-dashboard-p1.py` 28/28 OK; `node --check` clean;
  full `make -C automation test` rc=0.
- Live in-browser (relay tab, http://127.0.0.1:8890/): masthead
  "2026-09-27 · all-clear"; lead editorial renders; Decisions sheet =
  ONE flood card with "Dismiss all 40" / "Keep them" choices and
  outcome previews; Sessions/Research/Alerts articles print open with
  kicker/headline/deck/body; System sheet honest; arrow-key page turn
  snaps (scrollLeft 1203 ≈ one viewport); `Cache-Control: no-store`
  on `/` after unit restart.
