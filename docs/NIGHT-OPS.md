# NIGHT-OPS — the overnight automation manual

For any agent session that wakes unattended (night-agent 00:00/02:00/04:00/06:00,
morning-report 07:30) and for the 8am human. Read this first, every time.

## Current state snapshot

- Harness home: `/home/bricker/Projects/etc/hngh-automation` (this repo).
- Live timers (systemd --user): `hngh-automation.timer` (hourly research ping),
  `hngh-security.timer` (4h repo/security check + repo traffic stats),
  `hngh-morning.timer` (06/07/08/09 digests), `hngh-night-agent.timer`
  (00/02/04/06 wake sessions), `hngh-morning-report.timer` (07:30 report),
  `hngh-night-research.timer` (23:40 free local-model research brief),
  `hngh-model-bench.timer` (01:10 daily overnight fleet bench between the
  00:00 and 02:00 wakes; results in `stats/model-bench-<date>.jsonl`).
  Dashboard service on :8890
  (http://192.168.0.186:8890).
- Night sessions: `scripts/night-session.sh <prompt-file> <label>` runs one
  budget-capped `omp -p --model zai/glm-5.3` session (timeout 900s). The
  session-count ledger is `logs/budget.md`; the runner REFUSES to start once
  it counts 6 `session-run` lines (hard ≈ $30 ceiling guard). Logs land in
  `logs/night-<label>-<ts>.log`.
- Hngh core: `/home/bricker/Projects/etc/hngh` — promotion rung 12 landed
  2026-08-25 (pinned-key registry + signature-verification transport; see
  docs/records/2026-08-25-r12-pin-registry-and-signature-transport.md).
  Gate: `make test` = 8 reader guards + 2,663 checks. Self-governed commits
  only; verified commits may be pushed to origin.
- Pushes to origin are now cyclic: `cadence/hour/16-remote-push.sh` pushes
  both repos' default branches at most once per `push-cadence-hours`
  (default 24h), gate-gated, never forced, skipped when anything is staged.
- Budget reality until 2026-08-29: **zai/glm-5.3 ($30 credit) is the ONLY paid
  model available.** OpenRouter and Kimi are locked. Night sessions must not
  use any other paid API. Local Unsloth/ollama models are free and unlimited.

## Resume protocol (a fresh session picking up cold)

1. `tail -n 15 STATE.md` here — the breadcrumbs tell you what happened.
   If the box just came back up (crumbs older than `resume-gap-hours`,
   default 6h): `bash jobs/resume-pass.sh --boot` writes
   `logs/resume-<date>.md` — dead sessions with cause, held plans, missed
   day beats, open operator items. The day tier runs the same pass
   automatically (`cadence/day/15-resume-pass.sh`); transient-cause dead
   sessions are then respawned at most once/day by the bounded executor
   (`jobs/agent-respawn.sh`, 30m tier).
2. `git -C . log --oneline -5` and `git -C /home/bricker/Projects/etc/hngh log --oneline -5`.
3. Check dashboard freshness: the `generated_at` field of `dashboard/data.json`.
4. `systemctl --user list-timers 'hngh-*'` — every timer scheduled, none failed.
5. Decide: healthy → append one check breadcrumb and exit. Something broken →
   bounded repair (below), breadcrumb, exit.

## Troubleshooting bounds (night agents)

- Restart a failed timer/service: `systemctl --user restart <unit>`.
- Dashboard stale > 2h: run `make smoke` from this directory (real fetches +
  real local model + dashboard regen; adds today's data — that is fine).
- Model servers: Unsloth (`$UNSLOTH_URL/v1/models`) then ollama
  (`$OLLAMA_URL/api/tags`) — both free; if both are down, jobs fail closed
  (archive-only) and you just log it.
- Commit harness state locally: `git add STATE.md logs/ && git commit -m "night: state checkpoint <ts>"`.
  NEVER push this repo; NEVER edit the hngh repo; NEVER create new systemd
  units; NEVER spawn task subagents; NEVER call a paid API other than this
  session's own zai/glm-5.3.

## Morning checklist (the 8am human)

- `logs/MORNING-REPORT.md` exists (written by the 07:30 session) — read it.
- Dashboard shows: hourly pings overnight, 06/07/08/09 digests, research brief
  (`digest/RESEARCH-<date>.md` from 23:40), night-agent breadcrumbs in STATE.md.
- `systemctl --user list-timers 'hngh-*'` — 7 timers + dashboard service active.
- `git -C /home/bricker/Projects/etc/hngh log --oneline --since="18 hours ago"`
  — expect the rung-12 commits if you slept through them.
