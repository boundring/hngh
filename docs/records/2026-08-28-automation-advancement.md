# 2026-08-28 — automation-advancement review

Scope: how much of the operator session's own working pattern the machine
now runs itself, after the self-improvement cadence wave (hngh-automation
`34cd275`, `232c5fe`; hngh `3a112a6`) and the Winamp/docs wave
(`5a4ac12`). Evidence: the cadence trees, day-tier drop-ins, hourly
self-review + ui-audit, and the mechanisms listed in
architecture-index.md. Command: none — this is a mapping, not a bench
result; every claim cites a landed artifact below. Remaining unknowns:
none for the mapping; the next-necessary list is forward work.

## The session pattern, step by step

| Step | Automated today | Evidence |
|---|---|---|
| Intake → plan | No — operator-directed, agent-authored | session-notes; roadmap working order |
| Execution | Yes, per-tier | `cadence/{1m,5m,10m,30m,hour,day,week,month}/*.sh` |
| Verification | Yes, daily | `cadence/day/03-gate-check.sh` (`make test`, 2,855 checks) |
| Review | Yes, daily | `cadence/day/04-review-prep.sh` (`digest/REVIEW-<date>.md`; P0/P1 alerts) |
| Research | Yes, daily | `cadence/day/05-research-beat.sh` (`digest/RESEARCH-BEAT-<date>.md`) |
| Ledger hygiene | Yes, daily | `cadence/day/02-ledger-prune.sh` (48h retention, deletions alert) |
| Self-watch | Yes | oversight (5m), loop recognition, roguelike watchdog, agent supervision/auto-replace |
| Dashboard honesty | Yes, hourly | `cadence/hour/00-dashboard-self-review.sh`, `cadence/hour/05-ui-audit.sh` |
| Surface evolution | Yes | `cadence/10m/01-evolve-ui.sh` (evolve-dashboard-style) |
| Routine project activities | Yes, matrix-driven | `cadence/day/01-activity-tick.sh` per activity-matrix.md |
| Commits | Hybrid — plain `fix:`/`feat:`/`docs:` commits in hngh-automation; certificate loop in hngh is agent-run and now fired autonomously by the overnight beats (first runs were operator-initiated) | ceremony-drive; two waves of ceremonies this day |
| Records writing | No — agent-authored, ceremony-landed | docs/records/2026-08-28-*.md |
| Doc routing | No — agent-authored | this wave's docs edits |
| Telemetry | Capture only | `jobs/telemetry.py` (no readers yet, by design) |

## Honest read

The machine verifies, reviews, researches, prunes, watches itself, and
evolves its own surface on cadence. As of the overnight loop
(hngh-automation `3f4ad10`) it also executes and lands its own work:
plans are operator-authored and operator-accepted (today's plan,
docs/project/plans/2026-08-28-overnight-continuity.plan.md, was
accepted 2026-08-28T03:20:00Z before machine execution began), the
overnight cycle executes the accepted steps through bridge-gated
delegated sessions, and landing is certificate-driven — plain commits
in hngh-automation, the full ceremony loop in hngh. The only barrier is
governance itself (certificates + green gates); human approval covers
plan authoring and acceptance at every risk class, and beyond that is
reserved for the critical class: provider/credential configuration,
systemd unit lifecycle beyond installed units, non-prune deletions,
and security posture. Blocked work parks with an operator-facing alert
and the cycle moves on — research lines are the filler, so the machine
never idles on a human.

## Next-necessary (recorded, not built here)

1. Telemetry readers — capture-before-views is satisfied; the store has
   day-old data and the specs' views (session-cost, research cost) are
   the intended first consumers.
2. Session-cost capture per ledger-and-records-spec.md (the sessions-feed
   aggregation flagged adjacent in the cadence wave).
3. Watchdog/oversight consuming day-tier rows (gate-red alerts already
   land in the ledger; arming on them is wiring, not new machinery).
4. ui-audit findings feeding oversight (the alert identities are already
   per-rule; a 5m consumer needs only a read).
