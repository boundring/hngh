# Phase 2: Atomic Claim/Release + M7 Task Projections

**Status:** Design spec, 2026-08-02. Author: Hermes (GLM-5.2, PM/designer lane).

## Problem

Hngh records tasks and admits them to the queue (v3). It cannot yet safely
assign a task to a specific agent, prevent duplicate work, or gate completion
behind verification. The role-gate incident (artifact 61) proved this is not
theoretical: a worker consumed an owner-gated task before the blocker message
arrived.

## Goals

1. **Atomic claim**: exactly one agent holds a task at a time.
2. **Role-gated dispatch**: a task's `:allowed-roles` controls who may claim.
3. **Authority enforcement**: `:authority :owner` or `:authority :operation`
   tasks cannot be claimed by workers.
4. **Verifier-gated completion**: only the named `:verifier` may transition a
   task to `:done`.
5. **M7 projection**: the daemon exposes `claim`, `release`, `status`, and
   `ready` operations over the wire protocol, emitting events on each
   transition.
6. **Failure handling**: failed acceptance becomes `:blocked` or `:failed`,
   never `:done`.

## Data model (extends queue v3)

```lisp
;; Task record additions (v3.1)
(:claimant "agent-name"           ; who claimed, or nil
 :claimant-role :worker           ; role at claim time
 :claimant-route :local-12b       ; route used
 :claimed-at 1234567890           ; universal-time
 :lease-expires-at 1234568050     ; universal-time, claim + lease-seconds
 :verifier "terra"                ; named verifier, or nil
 :allowed-roles (:worker :coder)  ; roles permitted to claim
 :authority :worker                ; :worker | :owner | :operation
 :verification-command "make test"; command the verifier runs
 :last-failure nil                ; (:class :schema :reason :at)
 :transition-log ()               ; list of (:from :to :at :by :reason))
```

## State machine

```
:queued -> :claimed -> :done
                  \-> :blocked -> :queued (re-queue)
                            \-> :failed
:claimed -> :claimed (lease renewal)
:claimed -> :queued (release or lease expiry)
```

Transitions:
- `claim`: `:queued` -> `:claimed`. Requires: claimant role in
  `:allowed-roles`, claimant has current ROLE-ACK, authority permits
  claimant's role. Atomic: read queue, find task, check guards, write
  updated record. If any guard fails, return error, do not write.
- `release`: `:claimed` -> `:queued`. Requires: claimant matches, or
  lease expired. Clears claimant fields. Records transition.
- `complete`: `:claimed` -> `:done`. Requires: caller is the named
  `:verifier`, or caller is the claimant and `:verifier` is nil and
  `:authority` is `:worker` (self-verify for trivial tasks). Records
  transition, emits `:task-completed` event.
- `block`: `:claimed` or `:queued` -> `:blocked`. Requires: caller is
  claimant or verifier. Records `:last-failure` with class, reason,
  evidence path. Emits `:task-blocked` event.
- `fail`: `:claimed` -> `:failed`. Requires: caller is verifier or PM.
  Terminal unless PM re-queues. Emits `:task-failed` event.
- `re-queue`: `:blocked` -> `:queued`. Requires: caller is PM or
  designer. Clears claimant fields, preserves `:last-failure` in
  transition log. Emits `:task-requeued` event.

## Lease management

Default lease: 300 seconds (5 minutes). Configurable per task via
`:lease-seconds`. The scheduler tick checks for expired leases and
releases them automatically. A claimant may renew by calling `claim`
again before expiry.

## M7 wire protocol additions

```
;; Request types
(:claim-task id :role role :route route)   -> (:ok task-record) | (:error reason)
(:release-task id :reason reason)         -> (:ok) | (:error reason)
(:complete-task id :evidence evidence-path) -> (:ok) | (:error reason)
(:block-task id :class class :reason reason :evidence path) -> (:ok) | (:error reason)
(:fail-task id :reason reason)             -> (:ok) | (:error reason)
(:ready-tasks :role role)                  -> (:ok task-ids)  ; tasks claimable by role

;; Event types (published on transition)
:task-claimed    (:id :claimant :role :route :at)
:task-released   (:id :claimant :reason :at)
:task-completed  (:id :claimant :verifier :evidence :at)
:task-blocked    (:id :claimant :class :reason :evidence :at)
:task-failed     (:id :reason :at)
:task-requeued   (:id :from-block :at)
:lease-expired   (:id :claimant :at)
```

## Tests (fixture-based, RED first)

1. Worker claims a `:worker`-authority task -> `:claimed`, event emitted.
2. Worker attempts to claim `:owner`-authority task -> error, no state change.
3. Worker attempts to claim with role not in `:allowed-roles` -> error.
4. Verifier completes a task -> `:done`, event emitted.
5. Non-verifier attempts to complete -> error.
6. Claimant blocks a task -> `:blocked`, `:last-failure` recorded.
7. PM re-queues a blocked task -> `:queued`, failure preserved in log.
8. Lease expires -> auto-release, `:lease-expired` event.
9. Second agent attempts to claim an already-claimed task -> error.
10. Claimant releases -> `:queued`, second agent can claim.
11. Failed acceptance (`block` with `:class :verification`) -> `:blocked`,
    never `:done`.
12. `ready-tasks` for a role returns only claimable tasks for that role.

## Implementation order

1. Add v3.1 fields to `normalize-task-record` and validation.
2. Implement `claim-task`, `release-task`, `complete-task`, `block-task`,
   `fail-task`, `ready-tasks` in `ai-orchestrator.lisp`.
3. Add lease-expiry check to scheduler tick.
4. Add wire protocol request handlers in `daemon.lisp`.
5. Add event publication on each transition.
6. Write tests (RED first, then GREEN).

## Non-goals

- No agent process management (squad-up/down already exists).
- No model routing selection (M8 is a separate wave).
- No automatic retry logic beyond lease expiry.
- No multi-agent bidirectional task queue (Beads-style) — this is
  single-owner, one-claim-at-a-time.

## Security

- `*read-eval* nil` on all queue reads/writes (already enforced).
- Authority checks are fail-closed: unknown authority -> error.
- Verifier identity is checked against the declared `:verifier` field,
  not against model self-identification. The daemon trusts the caller's
  declared role, but the PM (human or Terra) can override any state.

## ROLE-ACK lookup source

**Decision:** The claim request carries the claimant's declared role and
agent identity as parameters. The queue does NOT look up OptMem or any
external registry to verify the declaration.

Rationale:
1. OptMem is a shared-memory signpost system, not an authority store.
   It has no atomic semantics, no schema, and no guarantee of freshness.
2. The queue is the authority. It records what was declared at claim
   time. If the declaration was false, the transition log preserves the
   evidence for audit.
3. The verifier gate is the real enforcement: even if a worker lies
   about its role to claim a task, it cannot mark the task done — only
   the named verifier can.
4. The PM (K3 or human) can revoke a claim at any time by calling
   `release-task` with a reason.

Callers pass `:role` and `:agent` in the claim request. The queue stores
them in `:claimant-role` and `:claimant`. The `:allowed-roles` field on
the task is checked against the declared `:role`, not against any
external lookup.

This keeps the queue self-contained, testable with fixtures, and free
of external dependencies on OptMem or any other shared state.