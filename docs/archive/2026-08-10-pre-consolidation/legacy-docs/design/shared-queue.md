# Shared Queue Contract

**Status:** Version 3 record validation is implemented. Dispatch, claims, and
client projection remain later phases.

## Purpose

Hngh keeps task records as the machine-wide source of truth. Clients, squads,
night runners, journals, and dashboards project those records; none maintains a
competing task state.

## Compatibility

- Version 2 records remain valid and retain their current behavior.
- A record without `:schema-version` is normalized as version 2.
- Version 3 records retain their schema during normalization.
- Unknown schema versions fail closed.

## Version 3 fields

| Field | Type | Meaning |
|---|---|---|
| `:type` | `:plan`, `:research`, `:work`, `:operation` | Task class and authority path |
| `:assigned-role` | `:coordinator`, `:worker`, `:reviewer`, `:scout` | Intended operating role |
| `:input-artifacts` | list of strings | Immutable source or context references |
| `:output-artifacts` | list of strings | Produced artifact references |
| `:verification` | plist | Verification command, status, and observation time |

A verification plist has this shape:

```lisp
(:command "make test" :status :pending :observed-at nil)
```

`:command` is a string or `NIL`; `:status` is `:pending`, `:passed`, or
`:failed`; `:observed-at` is an integer universal time or `NIL`.

Version 3 defaults are conservative:

```lisp
:type :work
:assigned-role :worker
:input-artifacts ()
:output-artifacts ()
:verification (:command nil :status :pending :observed-at nil)
```

Validation is structural. Eligibility, atomic claims, harness launch, and the
rule that a completed task requires successful verification are later phases.

## Event contract

Queue admission publishes this event when the event bus is active:

```lisp
:task-queued
(:id <integer> :status :queued :schema-version 2)
```

Event delivery is best-effort and cannot roll back a successfully persisted
queue entry. Consumers must obtain authoritative task state from the task
store, not solely from an event stream.

## Authority boundary

The existing task authority checks remain unchanged in this phase. The planned
record types map to policy as follows:

- `:plan`: human-reviewed intent; it does not execute.
- `:research`: source-grounded, artifact-out work only.
- `:work`: bounded code, documentation, or configuration change with declared
  verification.
- `:operation`: installation, service, publish, or privileged action. It must
  begin proposed and requires explicit human approval before execution.

## Next phases

1. Atomic claim/release and M7 task projections.
2. Night-queue import/export adapter.
3. Squad adapter with independent reviewer verification.
4. Tool and MCP registry as approval-gated operation tasks.
