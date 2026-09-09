# Roguelike orchestration — the machine that plays itself

Status: DESIGN — operator direction, 2026-09-09. Companion to
[autonomous-development-control.md](autonomous-development-control.md)
(governance doctrine), [rehearsal-and-self-order.md](rehearsal-and-self-order.md)
(the rehearsal lane), and
[../records/2026-09-09-operator-flexibility-doctrine.md](../records/2026-09-09-operator-flexibility-doctrine.md)
(policy fluidity, meta-optimization priority).

> Roguelikes are not hard because they kill you. They are fair because
> they tell you, afterward, exactly what did.

## The map

The vocabulary is posture, not data: no ledger row, certificate, or
front-matter field carries these words. The ledgers stay literal
(dispositions, verdicts, breadcrumbs). The metaphor earns its place
only where it predicts behavior.

| Roguelike term | Mechanism | Where it lives | State |
|---|---|---|---|
| Death and rebirth | session die+replace: classify, brief, respawn | `automation/lib/launch-session.sh`, `automation/lib/causes.sh`, `automation/handoff_briefs/` | implemented |
| Save file | the handoff brief | `automation/handoff_briefs/*.md` | implemented |
| New-game-plus | pre-digested context pack regenerated at launch | `automation/lib/context-pack.sh` via `context_pack` | implemented |
| Difficulty pacing | fail-first speed ladder, FF_SPEED full/standard/cautious | `automation/lib/failfirst.sh` | implemented |
| Permadeath barrier | certificate gates + green `make test` | `scripts/ceremony-drive`, `src/adapter/mutation.lisp` rechecks | implemented |
| Respawn point | commit-per-green boundaries | standing rule; every green slice is committed before the next | implemented |
| Dreams | rehearsal lane on scratch stores | [rehearsal-and-self-order.md](rehearsal-and-self-order.md); plan 2026-09-09-rehearsal-lane | aspirational (proposed) |
| Meta-progression | curator beat over the work graph | [work-visualization-direction.md](work-visualization-direction.md) | aspirational (skeleton planned) |
| Party | parallel slots within the session ceiling | `failfirst_concurrency`, overnight-cycle batch slots | implemented |
| Companion device | the deck node | `automation/docs/DECK-NODE.md` (Phase 2 landed, Phase 3 pending) | partially implemented |

## What each mapping pins down

**Death is cheap because nothing unsaved was real.** A delegated
session runs behind `launch_session` (`automation/lib/launch-session.sh`):
one launch path, a timeout that lands on the process-tree root, and a
disposition spine — `LAUNCH_DISPOSITION` is `cancelled` or `dead` in
the existing ledger vocabulary. The watchdog
(`jobs/agent-respawn.sh`) reuses the exact launch path to respawn;
`lib/causes.sh` classifies the corpse from the log tail. A dead
session's last words become a classified cause, not a mystery.

**The handoff brief is the save file.** A brief in
`automation/handoff_briefs/` records role, autonomy rules, tunables,
and ledger paths — enough for a replacement session to act without
re-deriving the run. The wake prompt adds the new-game-plus layer:
`context_pack` regenerates the pre-digested repo context at launch
time, so the respawn starts stronger than the original spawn. The
2026-09-03 agent-stall die+replace is the worked example: the brief
(`2026-09-03-routed-agent-stall-omp-impl-phase1-5daa4e.md`) carried
role, autonomy boundary, tunables, and ledger paths, and the
replacement session landed its slice without re-deriving any of it.

**Difficulty is a state machine, not a vibe.** `failfirst.sh` runs
additive increase, multiplicative decrease: `full` every tick, one
demotion on a degraded outcome, promotion after three consecutive oks
(`failfirst-promote-threshold`). Degradation lowers difficulty;
recovery raises it — and the ladder tunes pace and concurrency, never
the spend ceiling. Honest note: the rungs pace the attempts; they do
not yet feed any difficulty readout to the operator.

**Permadeath is the gate, and it protects the living.** Nothing lands
outside the certificate loop (`scripts/ceremony-drive`: create-run,
admit-transport, propose, issue-cert, mutation-check) with a green
`make test`; the mutation executor rechecks every certificate fact
against fresh evidence before any Git command. A session that dies
mid-slice loses only its uncommitted breath — commit-per-green makes
every verified boundary a respawn point, so death costs the current
slice and nothing before it. This is why the machine can run 24/7:
the run never ends when a character does.

**Dreams are the save-scumming we permit.** The rehearsal lane runs
the same certificate loop against scratch stores with the mutation
tail removed — the run gets to see the consequence of an action
before paying for it, and the fail-closed rule keeps what it learned
as filed evidence, never as authority. Aspirational: the lane's plan
(2026-09-09-rehearsal-lane) is proposed, not executed.

**Meta-progression is the repo, not the session.** A session dies
with nothing; the work graph
([work-visualization-direction.md](work-visualization-direction.md))
keeps everything — plans, steps, unlock edges, parked-because
dispositions, last outcomes. The curator beat (aspirational, skeleton
planned) is the character sheet being maintained: dependencies
learned across runs, difficulty state justified by evidence,
duplicate builds retired with citations. The deck node
(`automation/docs/DECK-NODE.md`) is the companion: Phase 2's model
endpoint lends VRAM to the party; Phase 3's research beat would give
it a turn.

## Roadmap rungs: what formalizing this buys next

Each rung is aggregation over ledgers that already exist. No new
clock, no new authority; all of it rides stage 1 (self-watch) and
stage 5 (research beats) of the roadmap stage table
([../project/roadmap.md](../project/roadmap.md)) — the map adds no
stage of its own.

1. **Session-death telemetry as difficulty telemetry.** `logs/budget.md`
   rows and the `lib/causes.sh` bestiary already record every death
   with a classified cause. Aggregate deaths per day per cause and
   compare against the failfirst state file: a `full` speed with a
   rising stall-cause count is the ladder lying to itself. Missing
   piece: one daily aggregation job; the difficulty readout for the
   operator falls out of it.
2. **Handoff-brief quality scoring.** Briefs exist; their quality is
   unmeasured. Score a brief by its replacement's time-to-first-useful
   action (already visible in budget rows and logs) against a no-brief
   baseline. A bad save file is a cause, not a vibe.
3. **Dream-run statistics feeding bench calibration.**
   `jobs/model-bench.sh` scores exactly five probes to decide the
   local model's trust. Dream runs (rehearsal lane) would produce
   propose-refusal and verdict statistics per model for free — a
   continuous bench instead of a periodic one. Blocked on the
   rehearsal lane landing.
4. **Work-graph meta-progression visibility.** The curator skeleton
   plus the feed-layer graph upgrade give the gantt and story
   renderers real meta-progression: what the machine learned, what it
   retired, what it unlocked. Blocked on the work-graph builder
   (work-visualization-direction) and the curator beat.

## Explicit non-goals

- No new vocabulary in ledgers, certificates, or front matter — the
  metaphor documents, it never stores.
- No new stage, daemon, scheduler, or clock: every rung is a
  cadence-driven aggregation or a plan-lifecycle change.
- No rebalancing of the difficulty ladder inside this design: the
  fail-first engine stays as built; telemetry only audits it.
