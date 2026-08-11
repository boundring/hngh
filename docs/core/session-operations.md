# Hngh session operations

**Status:** DESIGN
**Authority:** lifecycle, afterlife, model-economy, and session-control baseline.

A session is a temporary execution lease. Hngh is the durable system. A session may produce evidence and a proposal; it does not own policy, task state, or memory.

## 1. The 24 operating laws

### Identity, scope, authority

1. Sessions are leases; Hngh retains durable truth.
2. One work package has one authority path.
3. Scope is a boundary, not a preference.
4. Authority is narrow and named.
5. The operator is the final authority.
6. Policy, implementation, and evidence are separate.

### Truth and work control

7. Evidence precedes narrative.
8. A baseline precedes a metric.
9. Metrics are decision aids, not theatre.
10. `UNKNOWN` is a first-class outcome.
11. Claims have one writer and a visible release.
12. Verification is independent of production.

### Session economy

13. Retirement is normal.
14. Failure is classified, not punished.
15. The compact handoff is the only default bridge.
16. Context is a budgeted physical resource.
17. Cost is bilateral and pre-admitted.
18. Least action beats forced continuation.

### Afterlife and adaptation

19. Afterlife is a reduction pipeline.
20. Chain of custody survives compression.
21. Lessons compete with prior lessons.
22. High capability teaches; low cost executes.
23. Promotion requires measured improvement.
24. Communication reports transitions, evidence, blockers, and next actions—not a conversational diary.

The Chuang Tzu restraint is operational: retain what proved useful, change the vessel freely, and do not force a stalled form to continue.

## 2. Session contract

No session starts without this minimum record:

```lisp
(:session-id :task-id :attempt-id :parent-session-id
 :role :route :provider :model :route-class
 :write-boundary :verifier :authority :budget-envelope
 :acceptance-command :stop-conditions :started-at)
```

A task card supplies the intent. The session contract supplies the permitted execution. A missing or malformed field refuses the session.

## 3. Lifecycle

```text
proposed -> admitted | refused
admitted -> running | cancelled
running -> checkpointed | awaiting-operator | retired
checkpointed -> running | retired
awaiting-operator -> retired
retired -> afterlife-pending
afterlife-pending -> closed | successor-ready | case-review
case-review -> closed | successor-ready
```

A worker cannot self-promote from `awaiting-operator`, `retired`, or `case-review`. A successor is a fresh lease with a new attempt id and a named next verification.

## 4. Terminal classification

Exactly one terminal reason is required:

```text
accepted | blocked | refused | expired | cancelled | failed |
policy-denied | budget-exceeded | context-exceeded | safety-incident |
external-unavailable | unknown
```

Contributing factors may be many. They do not overwrite the terminal class. “Death” is an internal metaphor for lease end, not a claim of blame or value.

## 5. Context and cost gates

A model window is not a working target.

| Stage | Window use | Action |
|---|---:|---|
| observe | below 12% | record components and evidence |
| warn | 12% or more | prepare a compact handoff at the next phase boundary |
| compact | 18% or more | summarize and respawn before unrelated work |
| refuse-continuation | 25% or more | reject new work unless reset loss is proven higher |

Every model call records both input and output bounds. Local and known-price workhorse routes are ordinary candidates. A remote route above the approved price threshold, or one with unknown price, is a reserve route: explicit authority, compact no-tools packet, multi-window admission, reservation, and actual-use reconciliation are mandatory.

## 6. Handoff and terminal receipt

```markdown
# HANDOFF-<seat>
route: <actual provider/model>
context-stage: <stage>
task: <card and one-sentence state>
write-boundary: <exact files>
evidence: <commands/artifacts>
next-action: <one action>
blocker: <none or exact gate>
```

```lisp
(:session-id :task-id :attempt-id :terminal-reason :ended-at
 :claim-state :deliverables :evidence-refs :next-action
 :usage-receipt :context-ledger :safety-events :redaction-class)
```

Unknown usage, route, or receipt data remains `:unknown`. A deliverable reference contains a path and digest, not copied transcript content.

## 7. Afterlife and lesson pipeline

```text
restricted raw evidence
  -> deterministic receipt/event extraction
  -> redacted local summary candidate
  -> duplicate search: case base + MisakaNet
  -> verifier: accept | adapt | reject | defer
  -> case-base record with source, evidence, and revisit condition
```

Afterlife code cannot change a claim, task, route, or policy. It produces candidate information only. Promotion requires a named card, a fixture or evidence source, and the correct authority.

## 8. Tiered guidance

A high-capability model is a bounded teacher: it returns a decision, invariants, counterexamples, unknowns, and an expiry/revisit condition. Cheaper workers transform that output into scoped cards, fixtures, adoption maps, and measured outcomes. A statement that cannot survive this descent has no execution authority.

## 9. Communication

A heartbeat is a state transition with evidence. A review is valid only for the exact diff or artifact inspected. A claim release is valid only when visible on the claim registry surface. A dead or stalled session does not justify a silent takeover.
