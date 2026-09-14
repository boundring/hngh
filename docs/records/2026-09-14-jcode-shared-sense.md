# 2026-09-14 — Jcode sessions as hngh agents: shared-sense design

Follow-up to `2026-09-14-omp-coexistence-review.md` and the completed
primary-harness plan. Operator framing: "each Jcode session is its own
little Hngh agent — those should be able to communicate with each
other and maintain shared senses and views."

## The mapping

A Jcode session maps onto the hngh agent model already:

| hngh agent property | Jcode session realization |
|---|---|
| Bounded run | one session, one working dir, loadout limits via run-start |
| Certificate consciousness | permission bridge (plan step 4): deny-by-default, cert-scoped allow |
| Spend attribution | budget row + `[Tokens]` log lines per session |
| Death and replacement | watchdog respawn via the gated launcher |
| Legibility | observatory rows, transcripts, git commits |

What was missing was the *communication* layer named as a design, not
scattered across files.

## Shared sense: three channels

1. **The ledger spine** — the repo as shared state: AGENTS.md brief,
   agent-handoffs.md, budget.md, agent-lessons, plan checkboxes.
   Durable; every session inherits what any session commits.
2. **Swarm channels** — jcode's native DM/broadcast/share/task-graph
   for live coordination under one coordinator. Perishable; anything
   that must survive gets committed.
3. **The observation trail** — sessions-feed rows, overnight logs,
   git log: asynchronous sense of sessions you never talked to.

Landed as the `hngh-shared-sense` skill (`~/.jcode/skills/`,
userspace, never committed to hngh — same doctrine as the
plan-proposal skill).

## Discipline (the hngh part)

- Read shared state before acting; write outcomes back.
- One writer per file per slice; coordinate through DM/share before
  touching a file a sibling read.
- Never write another session's state files — coordinate instead.
- Durable over perishable: commit the fact, message the pointer.

## Fanout: non-clobbering subagent swarms (2026-09-14 extension)

Swarm lanes (the nerve-center delegation fanout) inherit the
single-writer rule structurally, not by politeness: each subagent
lane works in its OWN working directory (jcode delegate launches
through `lib/jcode-delegate.sh` -> `lib/launch-session.sh`, one
working dir per slug) or, when lanes must share the checkout, on
disjoint file slices agreed up front (route/step headers name the
file set per lane). Only the coordinator commits shared surfaces —
a subagent never git-commits in the shared checkout, so two lanes
cannot clobber each other's staged index (the sweep hazard of
lesson 2026-09-14T08:44:40Z is unrepresentable when subagents do
not stage at all). Durable outcomes flow back the same way every
channel above does: the lane reports, the coordinator commits.

## Deliberately not built

No new shared-state machinery (no session-to-session bus, no central
agent memory service). The governed-fleet doctrine: coordinate through
setpoints in shared feedback loops — invariants, ledgers, thresholds —
never through a top-down dispatcher. The repo is the feedback loop;
git is the bus.
