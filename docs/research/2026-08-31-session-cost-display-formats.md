# session-cost display formats

Status: crystallized 2026-08-31 from research line `session-cost-display-formats`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-session-cost-display-formats.md.

Grounded rewrite 2026-08-31: the original crystallization was written
without access to this repo and invented a C-kernel mechanics layer
(`include/session.h`, `src/cost/display.c`, `/proc/hngh/session_cost`,
`/dev/hngh_cost`, timerfd/setitimer update loops) dressed as
"verification-driven actions". None of that exists here — Hngh is a
Common Lisp kernel plus no-daemon shell automation, and its cost
capture is already a real telemetry row. That mechanics layer is the
named foldback anti-pattern and is discarded; the line's real subject
survives: how session cost (tokens, money, model usage, duration) is
displayed across Hngh's actual surfaces.

## Findings (grounded rewrite)

- **F1 — the raw-vs-formatted question is already answered by the
  store.** `hngh-automation/jobs/telemetry.py` owns the schema:
  `events(ts, source, kind, identity, lane, unit, model, tokens_in,
  tokens_out, cost_usd, wall_s, subject, refs, body)` — raw integers
  (`tokens_in INTEGER`) and a numeric cost column (`cost_usd REAL`),
  never pre-formatted strings. The original doc's Finding 1 (display
  coupled with accounting) has no foothold: the only formatter is a
  presentation-layer script.
- **F2 — capture is landed; reading is not.** The spec
  (`docs/design/ledger-and-records-spec.md` §3, session-cost capture)
  landed 2026-08-28 (hngh-automation `232c5fe`): `jobs/session-cost.py`
  parses omp transcripts and emits one idempotent `kind=session-cost`
  row per finished session — model, tokens in/out, cost_usd, wall
  duration, identity = session uuid. The first read-only consumer is
  `hngh-automation/jobs/telemetry-report.py`, a CLI table. No dashboard
  surface renders these rows yet.
- **F3 — the identity half is rendered, the cost half is not.**
  `scripts/dashboard-readout` and `scripts/dashboard-tui` render live
  sessions through `scripts/hngh present` with structured identity:
  every `key=value` token (state, role, loadout, route, station, …)
  becomes its own field, mission joined whole, store name kept — plus
  age. The HTML/JSON spines carry the same fields. No cost column
  exists on any of these surfaces.
- **F4 — gating exists as loadout limits, not as display.** Cost and
  time discipline enters a session at creation via the hngh loadout
  (`loadout-cost-limit`, `loadout-time-limit`, …), which the readout
  shows as `loadout=...` in the session block. That is the only live
  cost-adjacent signal on a session pane today.
- **F5 — the 2026-08-28 line's conclusion is the still-unbuilt
  join.** That record's core position — one standard cost card,
  preflight/during/after, money-first, tied to execution gating — is
  not implemented anywhere; the raw rows for it exist but no surface
  joins them to the sessions view the spec's Sessions columns name
  (model, duration, cost, purpose).

## Recommendations (only where the real code shows a gap)

- **R1 — join captured cost to the rendered session identity.** The
  sessions panes already key on session identity (run id from `present`,
  roster id from store/record names); the telemetry store already keys
  `session-cost` rows by identity. A join feeding the spec's Sessions
  columns into the readout sessions table is the minimal realization of
  the 2026-08-28 cost card. Not established: whether the omp transcript
  uuid and the `present` run id line up one-to-one — verify before
  building the join.
- **R2 — display policy stays where the code already put it.** The
  store holds raw values; any rounding/staleness/precision policy
  belongs in the presentation layer when a cost column is added. The
  original doc's rounding-vs-truncation unit test is not established as
  needed — no formatter of fractional milliseconds exists in this repo.

## Grounding

Verified paths read while rewriting (2026-08-31):

- `docs/research/2026-08-28-session-cost-display.md` — the prior line
  in this exact subject (cost card, money-first, execution gating)
- `docs/design/ledger-and-records-spec.md` — telemetry/records split,
  schema v0 (`events(...)`), session-cost capture feeding the Sessions
  columns (model, duration, cost, purpose)
- `scripts/dashboard-readout` — session rows: every `key=value` token
  becomes a field (state/role/loadout/route/station/...), mission
  joined; HTML/JSON spines render run/state/loadout/mission/age —
  no cost field
- `scripts/dashboard-tui` — full-screen watch over the same spine,
  data readers imported from dashboard-readout (never duplicated)
- `hngh-automation/jobs/session-cost.py` — session-cost capture
  (kind=session-cost, identity=uuid, idempotent, live sessions deferred)
- `hngh-automation/jobs/telemetry.py` — the store schema
  (`dashboard/telemetry.db`)
- `hngh-automation/jobs/telemetry-report.py` — the CLI consumer of
  session-cost rows
- `hngh-automation/dashboard-server.py` and
  `hngh-automation/jobs/plan-feed.py` — the feed surfaces (sessions
  panes carry no cost fields today)

Discarded as ungrounded (the original crystallization's mechanics):
`include/session.h`, `src/cost/display.c`, `src/utils/units.c`,
`/proc/hngh/session_cost`, `/dev/hngh_cost`, timerfd/setitimer/
`timer_create` event-driven kernel updates, per-PID/per-TID kernel cost
attribution. Hngh has no C kernel and no kernel cost-tracking
interface; its cost capture is a telemetry row and its display
surfaces are shell/python readers over committed data and stores.
