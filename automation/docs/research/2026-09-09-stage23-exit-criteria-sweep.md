# Stage-2 / Stage-3 Exit-Criteria Sweep — 2026-09-09

Verification of the remaining stage-2 and stage-3 exit criteria. Evidence comes from the
dashboard-fetch agent (live HTTP checks against the SPA at `http://127.0.0.1:8890/`), the
overnight routed-agent logs under `logs/`, and the budget ledger `logs/budget.md`.

## Stage 2 — Dashboard up, all tabs identifiable

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| S2.1 | Dashboard serves a single-page app at `http://127.0.0.1:8890/` | **Verified** | dashboard-fetch: SPA loads at root; no server-side multi-page routing |
| S2.2 | All tabs reachable via hash routes: `#schedule`, `#sessions`, `#system`, `#research`, `#logs` | **Verified** | dashboard-fetch: each hash route returns HTTP 200 with identifying panel content |
| S2.3 | Each tab shows identifying panel content | **Verified** | dashboard-fetch: Camp·overview, Schedule·cascade, Sessions·observatory, System·host feed, Research·campaign board, Logs·reports & digest all present |
| S2.4 | Cold deep-links work (fresh load straight to a tab, e.g. `http://localhost:8890/#sessions`) | **Verified** | dashboard-fetch: cold deep-link to `#sessions` renders the Sessions·observatory panel |
| S2.5 | No unversioned REST surface exposed under `/api/*` | **Verified** | dashboard-fetch: `/api/state`, `/api/runs`, `/api/logs`, `/api/schedule` all return 404 (intentional; state is hash-routed SPA only) |

## Stage 3 — Full delegation cycle witnessed end-to-end

Cycle: run-start → observatory working (runs, incl. stall recovery) → run-end (plan marked closed).

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| S3.1 | Run-start observed in budget ledger | **Verified** | `logs/budget.md` rows for `overnight\|2026-09-03-routed-agent-stall-omp-hngh-interim-sweep-817ee7` at 00:30:34Z, 00:34:13Z, 01:09:39Z |
| S3.2 | Observatory working during the run (multiple session-runs, stall recovery) | **Verified** | Three session-run rows for the same plan; the 00:34:13 and 01:09:39 rows are the stall-recovery re-runs after the 00:30:34 start (cf. `docs/records/2026-09-04-transcript-stall-no-replace.md`) |
| S3.3 | Work output produced mid-cycle (handoff brief) | **Verified** | `logs/overnight-2026-09-03-routed-agent-stall-omp-hngh-interim-sweep-817ee7-20260908T203001.log` line 2: "Plan complete. Step 1 done: handoff brief written at `handoff_briefs/2026-09-03-routed-agent-stall-omp-hngh-interim-sweep-817ee7.md`, budget row appended to `logs/budget.md`." |
| S3.4 | Run-end observed: plan closed | **Verified** | `logs/overnight-2026-09-03-routed-agent-stall-omp-hngh-interim-sweep-817ee7-20260908T210150.log` line 2: "Plan `2026-09-03-routed-agent-stall-omp-hngh-interim-sweep-817ee7` is fully done — handoff brief written, budget row appended, plan marked closed. Nothing remaining to execute." |
| S3.5 | Full end-to-end cycle (start → work → close) witnessed for one delegated plan | **Verified** | Combining S3.1–S3.4: run-start 00:30:34Z → interim completion 20:30:01 log → closed 21:01:50 log; single plan id throughout |

## Not verifiable cheaply (explicitly out of scope for this sweep)

| Item | Status | Why |
|------|--------|-----|
| Browser-graded mobile-width sweep of the dashboard | **Not established** | Requires a graded viewport surface pass (narrow-width rendering checks); not exercisable via HTTP 200 checks alone. Defer to a graded surface pass. |
| Specific operator-item lifecycle (open → handled → dismissed) in `docs/project/reports.md` | **Not established** | Lifecycle transitions are operator-driven state changes; no automated trace of an individual item traversing all three states exists in the logs. |

## Verdict

- Stage-2 exit criteria: **verified** (all 5 rows).
- Stage-3 exit criteria: **verified** (all 5 rows) via plan
  `2026-09-03-routed-agent-stall-omp-hngh-interim-sweep-817ee7`.
- Two adjacent items remain **not established** and are listed with reasons above.
- `kernel make test` green (verified separately in this sweep's session).
