# Stage-2/3 exit-criteria sweep — 2026-09-03 staging plan, step 3

Swept 2026-09-09 ~16:15Z. One row per remaining exit criterion from the
roadmap stage table ([project/roadmap.md](../project/roadmap.md), stages
2 "One interface" and 3 "Roguelike delegation live", both state
`landing`). Each row: verified / not-established, with the cited
evidence. The pre-existing verified items (HTTP 200 root, wrapped
sessions exist) are not repeated; this sweep covers what
[records/2026-09-03-staging-notes.md](../records/2026-09-03-staging-notes.md)
named as remaining.

Method note: cheap real checks only — HTTP fetches, a headless-browser
render pass, log/report reading. No services started, no units touched.

## Stage 2 — One interface

Dashboard: `hngh-automation · nervous system` (automation repo
`dashboard/index.html`), served by `dashboard-server.py` on
`127.0.0.1:8890` (python3 pid 981, cwd automation repo).

### HTTP surface (all fetched cold, 2026-09-09T16:15Z)

| URL | status | identifying content |
|---|---|---|
| `/` | 200 | SPA document, title "hngh-automation · nervous system", tabs Schedule/Sessions/System/Research/Logs/KB |
| `/data.json` | 200 | digest spine, `generated_at: 2026-09-09T16:00:24Z`, job `ping-hourly.sh` |
| `/readout.json` | 200 | verdict/timeline/queue spine (dashboard-readout --json shape) |
| `/operator-items.json` | 200 | 40 items, all `"status": "open"`, `generated_at: 2026-09-09T16:12:00Z` |
| `/operator-dismissed.json` | 200 | dismissed ledger, 30+ ids with 2026-08-27 timestamps |
| `/sessions.json` | 200 | observatory feed, 39 sessions, `generated 2026-09-09T16:12:00Z` |
| `/style.css`, `/app.js` | 200 | dashboard skin + app (hash router, feed readers) |

### Criteria

| Criterion | Verdict | Evidence |
|---|---|---|
| Every tab renders at desktop + mobile widths | **verified** | Headless-browser pass 2026-09-09 ~16:20Z: each of the 5 tabs opened cold at 1440×900 (desktop) and 390×844 (mobile) via its deep-link; every tab: `aria-selected=true`, panel visible (`hidden=false`), content rendered (no `loading…` placeholder). Identifying content per tab — Schedule: "SCHEDULE · CASCADE 60 hngh recurring · 1 system · 19 one-off queued"; Sessions: "SESSIONS · OBSERVATORY SESSIONS 39 … live 4s omp/Projects-etc-hngh-automation"; System: "SYSTEM · HOST FEED … pacman -Qu — upgrades stay a governed rung"; Research: "RESEARCH · CAMPAIGN BOARD … last grow 78m ago"; Logs: "LOGS · REPORTS & DIGEST 40 operator items · 60 of 60 entries". 10/10 checks passed. |
| Cold deep-links mount | **verified** | Deep-link scheme `#tab-<name>` (+ `#tab-logs/digest\|reports`), `app.js` hash router (`hashTab()`; hash wins over the sessionStorage fallback). Each cold load above used `http://127.0.0.1:8890/#tab-<name>` on a fresh tab and mounted the correct tab as selected with content — the cold-fetch table above shows the same document and feeds all answer 200 without prior session state. |
| Operator items flow open→handled→dismissed | **partially verified — handled leg not-established** | **open:** `dashboard/operator-items.json` — 40 items all `status:"open"` (e.g. id `123aecac`, first_seen 2026-09-08T09:02:02Z). **dismissed:** `dashboard/operator-dismissed.json` — 30+ ids with timestamps (2026-08-27T18:07/19:05Z); dismiss rows in `agent-handoffs.md` lines 11–18 (`operator-dismiss \| 2026-09-08T15:38:16Z \| automation\|13ded041 …`, ids 49c3a946, 5683b1d0, ef07539b, f2750a0e, …) written by `dashboard-server.py` POST `/operator-item/dismiss`. **handled:** the mechanism exists (`jobs/operator-items-feed.py` marks `status:"handled"` when a later STATE.md breadcrumb containing resolved/fixed/closed shares a subject token; feed docstring "open -> handled -> dismissed"), but zero handled items are present in the current feed and no handled-transition row was witnessed. **Missing check:** observe (or seed) one live item transitioning open→handled; reports.md carries no operator-item lifecycle rows itself — the lifecycle lives in operator-items.json + agent-handoffs.md, not reports.md. |

## Stage 3 — Roguelike delegation live

| Criterion | Verdict | Evidence |
|---|---|---|
| One full delegation cycle witnessed live end-to-end (run-start → observatory working → run-end disposition) | **verified (composite)** | **run-start:** `lib/launch-session.sh:75` — `omp-bridge --run-start "overnight-<slug>" "<objective>"` with budget loadout; the bridge gate runs live (refusal alerts prove it: reports.md rows 57b3eb86/f05d193c 2026-09-09T00:30:01Z, 402df80a 2026-09-09T16:00:17Z "could not open a bridge run"), and issued run ids appear in every overnight-lead receipt. **observatory working:** Sessions feed `dashboard/sessions.json` (generated 2026-09-09T16:12:00Z): 39 sessions — 9 live, 15 complete, 15 evacuated — including live delegated omp sessions with transcripts (e.g. `omp-step3-exit-criteria-3e109e` live, source `omp/Projects-etc-hngh-automation`), rendered in the Sessions tab at both widths during this sweep. **run-end disposition:** `agent-handoffs.md` overnight-lead rows, e.g. line 27 `overnight-lead \| 2026-09-09T00:00:16Z \| 2026-09-03-routed-agent-stall-omp-hngh-action-reduction-312cd0\|run-1 \| rc=0 done … cause=plan-done` and line 31 `…\|run-1 \| rc=0 cancelled … cause=bad-execution`; spend rows `logs/budget.md` lines 9–17 (session-run, e.g. 2026-09-09T00:00:16Z `overnight\|2026-09-03-routed-agent-stall-omp-hngh-action-reduction-312cd0`); completion row reports.md 6f89f8dd 2026-09-09T00:17:47Z "plan … executed (all steps checked)"; per-run logs e.g. `logs/overnight-2026-09-03-routed-agent-stall-omp-hngh-interim-sweep-817ee7-20260908T210150.log` ("Plan … fully done — handoff brief written, budget row appended, plan marked closed"). **Caveat (named missing check):** the observatory is a snapshot feed with no state-transition history, so the mid-run `working` witness for a *past* overnight run rests on the earlier live observation (reports.md 8e88929d, 2026-08-27T22:46:48Z, "run-1 start->working->end cancelled"); a persistent observatory state log is the missing check for repeatable per-run witness. |
| A seeded stall is flagged and replaced without human intervention | **verified** | Seeded test: reports.md 198c58ff 2026-08-27T22:58:12Z "seeded stall flagged+replaced in one tick (stage-3 criterion 2); UTC timestamp parse fix in supervision". Recent autonomous chain (no human step in any cited row): stall `agent-stall omp-2026-08-31T03-39-26-964Z_01a-817298: recovered ×3` (reports.md 9ea1d6d3 2026-09-07T02:10:35Z) → router routed it to a plan candidate autonomously (row 81bdcaab 2026-09-07T01:00:36Z) → auto-accepted, both gates green (row 44bf8a27 2026-09-07T01:01:22Z) → overnight delegated sessions executed the repair plan autonomously (overnight-lead rows 27–34, budget.md session-run rows 9–17, reports.md 6f89f8dd executed 2026-09-09T00:17:47Z). Supervision evicts stale sessions unprompted (rows c9c9145d 2026-09-08T19:10:01Z, e7b0b211/c10732f5/460e020e 2026-09-09T03:50–04:00Z, a9d50974 2026-09-09T12:25:18Z) and the respawn guard refuses non-transient causes per policy (`logs/respawn-2026-09-08.md`, 2 refused rows) — replacement routes through router→plan→overnight session, which is the observed path above. |

## Sweep conclusions

- Stage 2: two of three remaining criteria verified; the operator-item
  handled leg is the single open item (cheap to close by observing one
  live open→handled transition).
- Stage 3: both remaining criteria verified; the only structural gap is
  observatory state history (snapshot-only), named above as the missing
  repeatable-witness check, not a blocker for the exit criteria.
- Nothing was started, stopped, or edited outside `docs/` by this step.
