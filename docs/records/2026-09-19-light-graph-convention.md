# Light-graph convention (2026-09-19) — how waves work from here

Decision: the 1024-node deep plan is parked (inspectable, not driven).
All future work runs as small light graphs in wave sessions.

## Convention

- One wave = one bead family = one light graph (<20 nodes) in the
  wave session's own plan (each session gets its own plan object;
  the cap binds per plan, not globally).
- Node kinds: explore → implement → verify, with depends_on only for
  real data dependencies. No machinery-grown sprawl: expand_node only
  when a node is genuinely too big for one worker turn.
- Close rule: every node closes with a typed artifact (findings,
  evidence file:line/commit, validation, open_questions, confidence,
  what_i_did_not_check). Bead closes carry commit + comment.
- Gate rule: critique gates that find gaps file them as beads when
  the plan is full, as nodes when it has room. Blocked reports are
  valid trail, never silent stalls.
- Idle rule (memory-hooks): DM idle sessions before spawning;
  completion wakes trigger reassignment checks first.

## Wave order (Jev-judged, operator-confirmed)

plan-drain → role-circulation → steals → tiger-specs + ACP follow-ons
→ per-beat triage → claim bridge → freshness enforcement.
