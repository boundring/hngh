# Supposed vs actual — zoom-out (2026-09-19)

Direct synthesis (plan full at 1024, no graph nodes).

## Supposed to happen (the designed loop)

1. Timer beats fire (11 timers) → research/ledger/digest work runs.
2. Jev triages per beat (fan-out: hottest + heat + collapse).
3. Workers claim beads (claim verb in prompts), execute, close
   with evidence comments.
4. Guards route around the operator (beat-skip, midnight, reroute).
5. Plan drains via family synthesis → beads → records → city-state.
6. City-state grows a block per close; morning digest carries triage.

All six components exist as files: model.sh, vip-gate.sh,
typesafe.py, city-state.py, morning-digest.sh, launch-session.sh.

## Why it isn't happening already

- Beats fire but research beats were the contention source; the
  reroute shifts local→kimi, which burns quota legs already thin
  (ZAI ~3d, ocgo ~2d, Kimi thin). Beats run, but on fallback legs.
- Triage fires only in morning digest (once daily), not per beat.
  Per-beat fan-out is designed, unwired beyond the digest.
- Claim verb landed today (e199e15f); no worker has used it yet.
  Chipmunk/cow/crocodile closed via reports, not claims.
- Guards work (verdict skip fresh, routing verified) but verdict-age
  logging just landed; staleness was invisible until today.
- Plan cannot drain through itself (1024 cap rejects injection);
  drain runs as direct synthesis (cow's 3 family records) instead.
- City-state exports but nothing reads it back except the digest
  triage block. The loop isn't closed: export → triage → work →
  export runs, but work→export is manual (my commits, not beats).

## Missing automation parts (ranked by unblock power)

1. **Per-beat triage call** (not just digest): one Jev fan-out per
   research beat, ~2/min safe lane. Unblocks autonomous routing.
2. **Claim routing in beat-spawned workers**: beats spawn sessions
   via launch-session.sh (verb present) but beats are timer-fired
   shells, not swarm assigns — no session to claim. Bridge needed:
   beat → bead claim → worker DM.
3. **Verdict freshness guard**: refuse verdicts older than N minutes,
   force refresh. Age logging landed; enforcement missing.
4. **Plan-drain runner**: family synthesis as a beat (weekly), so
   the cap drains itself instead of via operator sessions.
5. **Schedule learner**: 4-signal log landed; posterior + intensity
   function unwired.
6. **Budget governor**: spend instrumentalization before enforcement.

## Next actions

Per-beat triage first (highest leverage, smallest diff), then claim
bridge, then freshness enforcement. File beads for each; drive as
waves with idle pool (cow/crocodile) + chipmunk on steals close.
