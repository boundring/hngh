# 2026-09-14 — Omp coexistence review: surface inventory vs Jcode

Plan step 7 of `docs/project/plans/2026-09-14-jcode-primary-harness.plan.md`.
Doctrine: retirement is a named record per surface, never a default. This
inventory is the review trigger; each retirement lands as its own record
when the Jcode equivalent passes the same verification.

## Surface inventory

| Surface | Omp form | Jcode form | Status |
|---|---|---|---|
| Orientation brief | omp plugin skills + `omp-bridge --orient` | `docs/agent-notes/jcode-orientation.md` via AGENTS.md import; same `--orient` command | Jcode verified (`jcode run`, 3/3 questions) |
| Delegated worker lane | omp branch in `launch_session` (bili-wrapped) | `jcode` branch: SDK shim → CLI → omp fallback ladder | Jcode live, witnessed cycle |
| Spend pacing | zai caps via `model.sh zai_pace_blocked` | jcode holds own provider auth; pacing NOT yet ported to the jcode branch | **Gap: omp retains the paced lane** until Jcode pacing lands |
| Cost attribution | `ocgo-attribution.py` emitter (R2) | budget row `model=jcode/zai` + `[Tokens]` log lines | Jcode parity reached for the budget row; deep telemetry still omp |
| Plan proposal surface | `hngh_propose` (omp plugin tool) | `~/.jcode/skills/hngh-plan-proposal` skill over the same `omp-bridge --propose` CLI | **Closed 2026-09-14:** skill landed in userspace (never committed to hngh), verified via headless `jcode run` (2/2 questions) |
| MCP read tools | `automation/mcp/hngh_mcp_server.py` (registered for omp) | same stdio MCP server, Jcode `~/.jcode/mcp.json` registration | Shared; no retirement needed |
| Session observatory | sessions-feed omp rows | `jcode_rows` (24 live rows witnessed) | Both live; shared surface |
| Fail-first selector | overnight-cycle plan slots (omp executor default) | `session-executor=jcode` option | Both available; selection per lane |
| Self-steering lessons | `ocgo-agent-lessons.md` read/append | read side rides the prompt; append only fires on ocgo-attributed sessions | **Gap: lessons loop is omp-side** |

## Disposition

- **No retirement yet.** Every retirement candidate has either a Jcode
  gap (pacing, plan proposal, lessons append) or is a shared surface
  (MCP, observatory).
- **Next retirements, in order, when their gaps close:**
  1. Unpaced worker lane (omp) → once jcode-branch pacing lands, the
     unpaced omp fallback loses its reason to exist.
  2. Plan proposal surface → when a Jcode-native `hngh_propose`
     equivalent passes the same gate verification.
- **Never retire:** the MCP server (shared standard, harness-neutral);
  the observatory rows (source-tagged, additive).

## Verification basis

- Jcode orientation: headless run answered queue/roadmap/orient
  questions (plan step 1).
- Worker lane: witnessed cycle rc 0 + budget row (plan step 3).
- Permission bridge: 13/13 hermetic checks (plan step 4).
- Observatory: 24 live rows (plan step 5).
- Config lanes: sources verified on host (plan step 6).
