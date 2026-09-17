# Is the identity re-routing logic in `dropin:33-research-beat.sh` scoped to a stable key that survives re-routes, or does it invalidate per-identity completion state?

Status: crystallized 2026-09-16 from research line `fail-20260915-Is-the-identity-re-routing-logic-in-drop`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260915-Is-the-identity-re-routing-logic-in-drop.md.

# Crystallized research line

**Line:** Is the identity re-routing logic in `dropin:33-research-beat.sh` scoped to a stable key that survives re-routes, or does it invalidate per-identity completion state?  
**Lifecycle state:** contracting → crystallized  
**Verification posture:** No repository contents were available in this transition. Therefore no implementation claim below is asserted as verified from this repository or from `~/Projects/etc/hngh`.

## Findings

1. **The central question remains unresolved at the code level.**  
   There is no verified evidence that the identity re-routing logic uses a stable key, nor any verified evidence that it invalidates per-identity completion state. The distinction depends on how the routing key is derived and where completion state is stored.

2. **A stable-key design would require an invariant logical identity.**  
   If the re-routing logic keys state by a stable identifier — for example, a canonical user/agent/session-independent identity that remains constant across host changes, process restarts, or route migrations — then per-identity completion state can survive re-routes. This is a design criterion, not a verified fact about the repository.

3. **An invalidating design would likely key state to volatile fields.**  
   If the routing key incorporates ephemeral values — for example, hostname, PID, temporary token, network address, process-local memory, or route-generation counter — then re-routing can change the effective key and thereby orphan or discard prior completion state. Again, this is a plausible failure mode, not a verified finding.

4. **The prior material does not resolve the line.**  
   The supplied prior material records the research line and unrelated vault pointers, but it does not provide code excerpts, file contents, or kernel identity semantics sufficient to determine whether re-routing preserves completion state.

5. **No concrete repository claim can be made without inspection.**  
   Because I cannot verify that specific files exist or inspect their contents in this transition, I do not cite any concrete file paths as evidence. The named script `dropin:33-research-beat.sh` is part of the research line’s question, but its existence and behavior are not treated as verified here.

## Recommendations

1. **Inspect the routing key derivation in `dropin:33-research-beat.sh`.**  
   Determine which fields compose the identity key used for re-routing. Classify each field as stable or volatile. If any volatile field participates in the key, per-identity completion state is at risk of invalidation on re-route.

2. **Locate the completion-state store.**  
   Identify whether completion state is stored:
   - process-locally,
   - in a durable file,
   - in a database,
   - in kernel-managed state,
   - or in an external service.

   The persistence boundary determines whether re-routing can preserve prior completion.

3. **Check the hngh kernel repository for identity abstractions.**  
   Look for modules that define canonical identity, route migration, session continuity, or state invalidation. The relevant question is whether the kernel exposes a stable identity primitive that the dropin script should use.

4. **Add a re-route survival test.**  
   A minimal test should:
   - complete work under one identity/route,
   - trigger a re-route,
   - resume or query the same logical identity,
   - assert whether completion state is still visible.

   The expected result depends on the intended policy:
   - stable-key policy: state survives;
   - invalidation policy: state is explicitly cleared or orphaned.

5. **Document the invalidation policy.**  
   If state is intentionally invalidated, the behavior should be explicit and testable. If state is intended to survive, the key must be documented as stable across re-routes.

## Open threads

1. **What is the canonical identity key in the hngh kernel?**  
   Does `~/Projects/etc/hngh` define a stable identity primitive that survives host or route changes? This cannot be confirmed without inspecting the repository.

2. **Does `dropin:33-research-beat.sh` use that primitive, or does it construct its own key?**  
   If it constructs its own key, the stability of that key must be evaluated field by field.

3. **Where is per-identity completion state stored?**  
   The answer depends on whether state lives in process memory, a local file, a database, kernel state, or an external coordination service.

4. **Is invalidation explicit or accidental?**  
   If completion state disappears after re-routing, it may be due to:
   - intentional invalidation,
   - key mismatch,
   - storage scoping,
   - process termination,
   - or route migration without state handoff.

5. **What is the intended recovery semantics?**  
   The line should end with a clear policy: either completion state survives re-routes under a stable identity, or it is deliberately invalidated and must be recomputed.

## References

- Research line state provided in this transition: “Is the identity re-routing logic in `dropin:33-research-beat.sh` scoped to a stable key that survives re-routes, or does it invalidate per-identity completion state?”
- Prior material provided in this transition: research beat 2026-09-16 for this line.
- No concrete file paths from this repository or `~/Projects/etc/hngh` are cited here because their existence and contents could not be verified in this transition.
