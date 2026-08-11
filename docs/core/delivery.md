# Hngh delivery system

**Status:** DESIGN
**Authority:** work decomposition, current frontier, backlog intake, acceptance, and change control.

## 1. Work breakdown

| Stream | Outcome | Representative work |
|---|---|---|
| A. Control plane | cost-, context-, and authority-aware dispatch | quota truth, route admission, profiles, receipts |
| B. Session economy | disposable sessions with factual continuity | lifecycle ledger, compact handoff, retirement controller, afterlife reducer |
| C. Safe autonomy | observable, least-agency orchestration | claims, operation gate, sandbox, watcher, ACP control |
| D. Learning system | measured improvement rather than prompt folklore | case base, fixture benchmarks, teaching packets, route promotion |
| E. Operator product | useful Linux and development automation | dashboard, local runtimes, maintenance, backup/sync, research tools |
| F. Consultation evidence | redacted, reproducible case studies | charter, receipts, outcomes, limits, decision records |

A card belongs to one stream, has one primary outcome, and names every dependency it needs. Cross-stream work is sequenced, not hidden in one broad task.

## 2. Current frontier

Card 147's exact planner-fixture diff was accepted in
`records/2026-08-10-card-147-planner-fixture-review.md`. The review applies
only to that fixture baseline; it does not approve later source work.

| Order | Item | Gate before work advances |
|---:|---|---|
| 0 | Card 131 context component ledger | card 127 quota consumer boundary accepted; fixture-first contract |
| 1 | Card 132 compact handoff generator | card 131 data shape accepted |
| 2 | Cards 140–141 reset packet and retirement controller | handoff contract and dry-run fixtures |
| 3 | Cards 142–143 cost telemetry/scenarios | documented llmtrim receipt mapping and explicit unknowns |
| 4 | Cards 134/136/137 measured teaching and policy selection | local/cheap fixture baseline and case-base disposition |

The accepted crystallization direction is recorded in
`records/2026-08-10-crystallization-decision.md`. It proceeds through these
gates and bounded cards; it is not a separate bypass around them.

The active review record and the current task registry remain the immediate evidence sources. This table is an ordered index, not a substitute for them.

## 3. Work package template

```text
ID:
Outcome:
Stream:
Why now:
Dependencies:
Write boundary:
Excluded surface:
Authority:
Route class and budget envelope:
Verifier:
Acceptance command/evidence:
Stop conditions:
Handoff target:
```

Work may begin only when each field is concrete. “Investigate” is not an outcome; it becomes a bounded question, sources, expected artifact, and stop condition.

## 4. Acceptance and closeout

A deliverable passes only when the named verifier can inspect the fixed artifact and its evidence. Closeout records:

- accepted result or terminal classification;
- exact source/artifact identity;
- commands and receipts actually observed;
- claim release visible at the registry;
- compact handoff or explicit `none`;
- lesson candidate disposition;
- remaining follow-up as a new backlog item, not a hidden TODO.

## 5. Backlog intake

The live backlog is `docs/records/backlog.md`. New ideas enter as short records, not new design files:

```text
Idea:
Problem / beneficiary:
Proposed smallest useful outcome:
Evidence or source:
Risk / cost / privacy note:
Dependency:
Disposition: intake | research | design | queued | rejected | archived
Review trigger:
```

A design document is created only after the idea has a bounded outcome, source set, owner, and review question. An idea with no near-term decision stays in the backlog, not the working context.

## 6. Change control

A requested change must state: affected work package, reason, scope delta, cost/context impact, risk, alternatives, and verifier. The operator approves scope, budget, privileged action, release, and any change that weakens a safety boundary. Implementation follows only after the record changes.

## 7. Scheduling rule

Hngh uses dependency order, not manufactured dates. The critical path is the longest chain of gated work packages. Parallel work is allowed only when write boundaries, test resources, provider budgets, and verification ownership do not conflict.
