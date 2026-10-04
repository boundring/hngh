---
category: delegation/agents
persona: The Steward of Mandarins
status: seed
---

# Delegation & Agents — what hngh runs today

hngh delegates through two cooperating layers: an automation-tier beat loop and a kernel-governed run boundary. **The beat loop** (`automation/ng/`): `cadence.py` is the "executive cadence driver: one beat polls bd for open beads, classifies, emits judgments" (automation/ng/cadence.py:1) over a three-verb kernel contract — observe / judge / act (automation/ng/contract.py:3-9). Judgment is one typed seam: `jev.py` routes questions through `lib/typesafe.py` (fail-closed {} without TYPESAFE_API_KEY), pinned model `jev-1.13.0`, `CONF_MIN=0.5` below which answers degrade to UNCERTAIN (automation/ng/jev.py:16-27,126-145); `ask()` NEVER raises — any failure is ESCALATE (:151-152). Answer handling NEVER raises either; failures file `escalation.filed` events (automation/ng/cadence.py:274-284). Dispatch is capped (4 slice.proposed/UTC day, `HNGH_DISPATCH_DAY_CAP`; automation/cadence-params.tsv:54) — at cap, work defers rather than dies (automation/ng/cadence.py:300-307); park/escalate accumulates attempts so an "escalate" cannot re-fire forever (:330-341). Tiering keywords (gate, kernel, cert, scrub) and staleness force T1 (automation/ng/tiering.py:9-35); the watch kernel audits stale verdicts and unread bursts (automation/ng/watch.py:88-107); escalations surface as report-queue alerts `escalation:<bead>:<reason>` (automation/ng/surface_escalations.py:1-11). Jcode swarm sessions are bounds-checked read-only by `jcode_guard.py:1-2` (node cap).

**The governed delegation boundary**: `scripts/omp-bridge:2-25` gives an oh-my-pi session `--orient` (a pre-ground project-state brief), `--ceremony` (commit FILES through the certificate loop), `--run-start` (create a bounded hngh run — the fixed worker loadout's token/time limits ARE the session's delegated budget — and admit-transport worker), and `--run-end` (close with a client-validated disposition cancelled|evacuated|dead; disposition honesty: a bridge run never enters :running, so legal close from :created is `cancelled`). The bridge is an outer adapter — "never imports or mutates the hngh kernel" (:43-46). The plugin surface is `automation/omp-plugin/src/index.ts:33-37` (Hngh Propose / plan-status tools). Kernel-side, `src/adapter/worker.lisp:18-101` is a bounded task port (task label + payload, injected execute-worker, zero exit binds a `:worker :current` evidence fact, "a worker completion is evidence only"). Session recovery is documented ritual: die+replace handoff briefs record role, autonomy rules, tunables, and ledgers (automation/handoff_briefs/2026-09-03-routed-agent-stall-omp-hngh-interim-sweep-817ee7.md:3-20), with closures like `resolved-obsolete` and `resolved-recovered-in-place` carrying transcript-level evidence (automation/handoff_briefs/2026-10-03-routed-loop-signal-omp-DashCode-366f5d.md:3-24). The executor ladder is jcode -> omp; jcode is never curl|bash-installed (automation/bootstrap.sh:95-99).

## Open questions for web research

1. Delegation budget models: how do agent frameworks bind a sub-session's token/time limits to a parent's authorization (loadout-as-budget precedents)?
2. Typed intent classification with confidence floors (Jev's CONF_MIN + UNCERTAIN degradation) — tool-router confidence gating in the wild.
3. Die-and-respawn session recovery: continuity protocols for long-running agent fleets (checkpoint briefs, replay).
4. Park/escalate/cap state machines for autonomous triage loops — retry ceilings and halt conditions.
5. Observe/judge/act multi-kernel contracts vs MAPE-K and similar autonomic loops.

## Candidate external systems to survey

- LangGraph (supervision + budget semantics)
- OpenAI Swarm / Agents SDK (handoffs)
- CrewAI (role + delegation)
- Temporal (durable execution for agent runs)
- MAPE-K reference model
