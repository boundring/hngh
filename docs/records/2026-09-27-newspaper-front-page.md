# 2026-09-27 — Newspaper front page (dashboard cutover)

## What changed

- `automation/dashboard/index.html` is now **the newspaper**: a skeuomorphic
  front page ("THE DAILY — hngh-automation") rendering six column-sheet
  sections — Lead (readout verdict + day's top story), Operator Decisions
  (open operator items with handle/dismiss), Sessions, Research, Alerts,
  System — as expandable `details` articles.
- The old operator console moved intact to `automation/dashboard/console.html`;
  the two pages cross-link (newspaper header → "nerve center", console header →
  "newspaper"). `dashboard-server.py` serve-json/token-acl covers the new page;
  no server route changes were needed.
- New `automation/dashboard/newspaper-view.js` follows the house view-script
  pattern (IIFE, escape helpers, fail-closed `#papererr` banner, feed-stamp
  date honesty, no `setInterval` — polling stays `HnghPoll`). Horizontal CSS
  scroll-snap paging with arrow keys, ←/→ buttons, section menu, page counters.
- View-contract tests repointed: history/routes/graph/plan-acceptance tests
  now read `console.html` for console-only contracts; new
  `automation/tests/test-newspaper-view.py` pins newspaper contracts
  (registered in the automation Makefile `test` target).

## Live verification

- Real-browser pass (omp relay, 127.0.0.1:8890): masthead date `2026-09-26`,
  verdict `all-clear`, 43 rendered articles, 24 decision buttons, error banner
  hidden, `scroll-snap-type: x mandatory` active; ArrowRight turned the paper
  to the Decisions sheet; console.html kept its 11 tabs, token meta, and
  handle/dismiss flows; screenshots stored under `~/Pictures/Screenshots/omp/`.

## Context

Slice 6 of the approved course-correction plan
(`local://hngh-course-correction-plan.md`). Intent: the operator's first
surface each morning is a readable paper with decisions to make, not a
console. The console remains one click away for hands-on work.
