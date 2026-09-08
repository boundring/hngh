# 2026-09-01 — roguelike pattern design

Status: DESIGN
Date: 2026-09-01

## Scope

Design the "roguelike" development pattern for Hngh's autonomous operations,
given the token budget ceiling constraint. Key components:

1. **Session cost ceiling**: Each session has a hard token/cost limit.
2. **Death-and-replacement**: When a session exhausts its budget, it dies
   and is replaced by a new session with a fresh budget.
3. **Handoff briefs**: Before death, the dying session writes a brief
   capturing state, next steps, and context for the replacement.
4. **Steer-vs-die**: Cheap steer attempts (low-cost LLM calls) before
   committing to death-and-replacement.

## Design

### Session cost ceiling

- Per-session budget: $0.05 (configurable via HNGH_SESSION_BUDGET).
- Tracking: jobs/session-cost.py emits cost_usd per session; telemetry
  database tracks cumulative spend.
- Enforcement: scripts/router-tick.py checks session_cost against budget
  before allowing new session spawns.

### Death-and-replacement

- Trigger: session exhausts budget OR wall time exceeds 30 minutes.
- Process:
  1. Session writes handoff brief to docs/records/<date>-<session-id>-handoff.md.
  2. Brief includes: current state, next steps, open questions, context.
  3. Session exits with code 0 (clean death).
  4. Router tick picks up the handoff and spawns replacement session.

### Handoff briefs

- Format: markdown with sections:
  - **Status**: what was accomplished.
  - **Next**: what the replacement should do first.
  - **Context**: what the replacement needs to know.
  - **Open questions**: things the dying session couldn't resolve.
- Storage: docs/records/<date>-<session-id>-handoff.md.
- Lifecycle: cleaned up by sweep-artifacts.sh after 48 hours.

### Steer-vs-die

- Cheap steer: before death, try a low-cost LLM call (e.g., gpt-5.3-codex-spark)
  to determine if the session can finish with a small adjustment.
- Cost: < $0.001 per steer attempt.
- Decision: if steer succeeds, continue session; if it fails, die and replace.
- Implementation: jobs/steer-vs-die.py checks session state and attempts
  a cheap LLM call; returns "continue" or "die" based on response.

## Budget arithmetic

- Target: <$10/day total.
- Session budget: $0.05/session.
- Max sessions/day: 200 sessions × $0.05 = $10/day.
- Realistic: 50-100 sessions/day typical; 200 is the hard ceiling.
- Steer attempts: < $0.001 each; negligible against session budget.

## Verification

- jobs/session-cost.py emits cost_usd per session (already exists).
- scripts/router-tick.py checks session_cost against budget (to be added).
- docs/records/<date>-<session-id>-handoff.md format (to be standardized).
- jobs/steer-vs-die.py (to be implemented).

## Sources

- docs/project/plans/README.md (plan contract).
- docs/project/roguelike-agentic.md (death-and-replacement pattern).
- jobs/session-cost.py (telemetry capture).
- scripts/router-tick.py (router logic).
