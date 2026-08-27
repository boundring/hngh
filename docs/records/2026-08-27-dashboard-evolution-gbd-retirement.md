# Dashboard evolution + git-back-dots retirement

Dated: 2026-08-27.

## Scope

The operator's dashboard directives landed as four parallel slices plus a
retirement, each verified independently (several by Main's own browser
relay review, fresh-eyes adversarial):

1. **git-back-dots retired.** All 11 gbd units disabled; the tool's full
   history archived as a verified bundle at
   `~/Projects/back/git-back-dots/` (bundle + worktree snapshot + config
   copy + restoration README); uv install removed; lane repos at
   `~/.local/state/git-back-dots/` preserved — now owned by
   `jobs/config-backup.sh` (parity proven, agent-configs lane green and
   pushed after the scan learned that ALL-CAPS/`${VAR}` values are
   environment references, not secrets).
2. **Operator-item lifecycle.** "For the operator" items now flow
   open → handled (with resolving evidence line) → dismissed-as-viewed
   (per-item, persisted to `operator-dismissed.json` + a handoffs row);
   40 items structured; dismissal proven on an isolated fixture server.
3. **Server endpoints.** `dashboard-server.py` gained
   `POST /operator-item/dismiss` and `POST /spawn` (configurable
   launchers from `~/.config/hngh/ui-config.json`, key-only client
   access, transcript resolution reused from the sessions feed); a live
   Konsole spawn was proven and cleaned up.
4. **Session-per-column observatory.** The 4-state buckets became one
   column per session: historic + live transcript tail (120-line cap,
   keyed diff), deep links `#run-<id>` with state restore across
   navigation, onboarding legend, human receipt sentences
   ("created · … / admitted · … / closed: evacuated"), history strip,
   1-minute feed drop-in. Adversarial review found 7 issues (persistence,
   glued headers, plist soup, graveyard default, pop-in, jargon,
   overflow) — all fixed and re-verified live.
5. **Cascading gantt.** `gantt.html`: one row per queued rotation lane,
   ESTIMATE-labelled bars (ledger p50 → loadout time-limit → 30m
   default, source shown per row), dependency connectors, relative
   projected starts (never fabricated dates), zoom 6h/24h/72h, drag pan
   with now-clamp, past region showing actual day-precision timeline
   events. Adversarial review caught an off-canvas connector artifact
   (double ms-conversion) — fixed and re-verified. A second pass by a
   sibling owner found the deeper cause of the operator's "no bars at
   all" report: the connectors SVG had no position rule and consumed
   ~965px of normal flow, pushing every row ~1000px below the fold
   (bars existed but were off-screen at every zoom). Fixed (`.glines`
   absolute) plus a 6px min-width floor with outside labels for tiny
   bars, 6h default zoom, and recurring chips (`∷ recurring ×N (every
   ~interval)`) computed from the time ledger. Method note:
   element-count probes matched the `gtoolbar` class and missed it
   twice; only the rendered-geometry audit (bounding boxes at viewport
   coordinates) caught it — geometry, not DOM presence, is the
   verification standard.
6. **Dashboard self-review (scheduled).** `jobs/dashboard-self-review.py`
   + hourly drop-in: feed freshness vs tiers, feed validity, served
   marker regression, ledger/body drift; findings classified
   unacceptable-now / acceptable-for-now and deduped through
   report-queue identities. Also surfaced + fixed a dedup defect
   (newest-row-only matching) and a server gap (css/js/json are now
   served `Cache-Control: no-cache` after two heuristic-cache
   incidents).

## Evidence

- Browser-relay verification by both executors and Main (screenshots in
  `~/Pictures/Screenshots/omp/`); bun/node syntax checks; curl endpoint
  proofs with swept test artifacts; `systemctl` post-states.
- hngh-automation commits: `7a4041e`, `5138aa5`, `93b6fd4`, `a6e580c`,
  `fd5d658`, `744f806`, `744f806..f67f972` wave commits — Main committed
  all after per-slice verification.

## Lessons (llm-wiki)

- `debug-repro-sandboxes-only` (the reports.md incident, repaired
  7,083/7,083 with 0 mismatches); `long-gates-run-async-against-interjections`;
  `verdict-rule-drift-two-surfaces`. Browser-relay screenshot friction
  filed via report_issue.

## Remaining unknowns

- Gantt per-lane medians need a lane→unit mapping once wrapped sessions
  name lanes in their missions.
- Widget-grid layout (terminalfeed.io-inspired) and the QoL evolution
  cadence are queued as rungs; interface plurality (OMP session as
  primary, Konsole hosting) recorded in the observatory rung.
- gbd unit FILES remain on disk (disabled state); deletion was not
  requested.