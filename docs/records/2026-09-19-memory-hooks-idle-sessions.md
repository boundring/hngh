# Memory hooks against idle-session waste (2026-09-19)

Lesson (chipmunk, hygiene→steals): a completed session sat idle 20 min
holding a live-agent slot, blocking the third spawn — until the operator
asked why, and a DM reassigned it in seconds. Direct synthesis (plan full).

## The three hooks

1. **Slot ledger (before every spawn).** Run `swarm list`; count
   running vs ready/idle vs completed. Slots = 3 max. If an idle
   session exists, the next assignment goes to it by DM — never spawn
   first. Spawn only when all live sessions are genuinely running.

2. **Reuse-before-spawn rule (routing order).** Assignment routing:
   (a) idle session with matching context → DM; (b) idle session,
   fresh context in DM → DM; (c) no idle sessions → spawn. Fresh
   spawn is the last resort, not the default. (Stored as project
   memory `mem_1789831250492`.)

3. **Wake-on-complete protocol (reassignment trigger).** Every
   completion report / await wake is a routing event: before doing
   anything else, ask "does this freed session take the next queued
   assignment?" Only then consider the wake consumed.

## Coordinator checklist (on every wake)

- [ ] Which sessions just freed? What did they close?
- [ ] What is queued? Does a freed session fit it?
- [ ] DM-assign before spawning, always.
- [ ] Slots full and all running? Then queue, don't spawn.
