# jevify — dashboard feature inventory (2026-10-03)

Rubric: two-axis (operator value × fate), frozen in program plan Phase A. Bulk classification: typesafe/jev-1.13.0 via judge_batch (28 rows, job jdgb-15986c4945b8186a).
[override] = model verdict contradicted landed decisions/evidence (operator chose control-room end-form; plan constants); evidence wins.

| Feature | Value | Fate | Note |
|---------|-------|------|------|
| paper-shader (WebGL newsprint #paper-canvas) | none | kill | dies with broadsheet |
| mega-map (three.js r160, seed + fleet live) | observation | keep-promoted | primary control-room surface per operator decision |
| stream (newspaper articles/masthead/editions) | attention | kill | newspaper retires; attention moves to rail |
| ghostdesk (ghost-counsel, 12/day) | none | kill | |
| wire-categories (hnrss world/politics/…) | observation | kill | config-disable via news-feeds.tsv |
| fixture-edition (synthetic practice editions) | none | **flag-only** [override: model kill] | plan keeps it behind explicit test flag |
| choice-cards (verb cards POST /operator-item/*) | delegation | **fold** [override: model kill] | THE decision mechanism; moves to attention rail (handled/dismiss stores ride along) |
| settlements (decision digest article) | attention | keep-promoted | composer keeps producing; becomes console digest |
| story.html | none | kill | |
| gantt.html standalone | ceremony | **kill** [override: model keep] | page dies; gantt.js ENGINE stays (Schedule tab) — plan constant |
| sessions.html stub | delegation | kill | |
| feedback-form | observation | keep | operator feedback channel |
| desk.html (Installation Desk) | ceremony | keep | Phase E depends on it |
| camp (verdict pill, items, crumbs, spend) | attention | fold | verdict+items+spend → attention rail; crumbs/dispatch stay in panel |
| logs | attention | keep | |
| kb | observation | keep | |
| graph (ops graph 2D/3D) | observation | keep | |
| history | observation | **keep** [override: model fold] | panel retained; pane-render fix landed (ae51b255) |
| research (campaign board) | none→observation | **keep** [override: model kill] | live research.json feed from research-lines.tsv cadence; roadmap surface |
| schedule | delegation | keep | gantt engine host |
| sessions | delegation | keep | |
| system (host feed + safe ops) | observation | **keep** [override: model kill] | core machine observation; feeds map node detail |
| plans | ceremony | **keep** [override: model fold] | panel stays; ROUTES folds INTO it |
| routes | ceremony | fold | → Plans |
| columns-setting (broadsheet +/- buttons) | none | kill | replaced by settings drawer |
| winamp-theme | none | **keep** [override: model kill] | console's one fixed theme (glossary-documented); drawer may add plain later, not this program |
| btop-embed (GET /system/btop → tmux) | observation | **keep** [override: model kill] | re-homed to System/map node detail; only side-effecting GET, stays token-less GET behind server guard |
| sse (/events push) | observation | keep | poll discipline backbone |

Net Phase C kill list (features): paper-shader, stream, ghostdesk, wire-categories, story, gantt-standalone page, sessions-stub, columns-setting. Flag-only: fixture-edition. Fold: choice-cards→rail, camp→rail (partial), routes→plans.
