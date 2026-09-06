# Bestiary — the failure taxonomy

Status: DESIGN — 2026-09-06. The five cause classes behind the
Disposition station of [the Descent](descent.md).

Cross-links: [descent.md](descent.md),
[autonomous-development-control.md](autonomous-development-control.md),
[writing-register.md](writing-register.md).

Every failure the loop observes gets exactly one cause class. The class
picks the route. Wrong class, wrong route — so each entry below shows
what the class looks like in this project's own logs.

## Classes

### bad-execution

The system did the thing wrong. A red gate, a dead session, a plan whose
steps never ticked. The knowledge existed; the execution failed.

- Overnight-lead died rc=1 four runs in a row on the same plan
  (`hngh-automation/agent-handoffs.md:151-154`, 2026-09-05).
- The automation gate went red and stayed red — "gate: hngh-automation
  make test FAILED (rc=2)"
  (`docs/project/reports.md`, 2026-09-05T09:01:28Z, alert 87bf41f4).

### missing-knowledge

The system hit a question nobody has answered in-repo. Not a bug — a
gap in the record.

- The research beat has idled since 2026-08-31: all 22 research lines
  are crystallized (`hngh-automation/research-lines.tsv`; the newest
  beat file is `hngh-automation/digest/RESEARCH-BEAT-2026-08-31-*.md`),
  and nothing refills the subject list.

### missing-design

The system needs a decided policy that exists only as an open question.
Research would answer it; nobody gated grow work on the answer.

- The steer-vs-die threshold was researched on 2026-08-30
  (`docs/research/2026-08-30-steer-vs-die-threshold.md`) and remains
  unbuilt, so "steer or kill" is still judged ad hoc per session.

### missing-authority

The right action is known and blocked on permission. Only the operator
can grant it.

- The 2026-09-04 unsloth outage ended when a human ran
  `start unsloth-studio.service` — the ledger records the operator
  grant explicitly ("bricker@brickertop ran 'start
  unsloth-studio.service' ... resulting ActiveState=active",
  `docs/project/reports.md`, 2026-09-05T09:01:41Z, row dc80233f).

### obsolete

The artifact or behavior is past its use. Keeping it produces false
signals and re-work.

- Same-identity plan candidates regenerate while the fix never lands:
  the tree-skew alert was re-routed into ten candidate files on
  2026-09-05 alone (`docs/project/plans/2026-09-05-routed-tree-skew-hngh*.plan.md`,
  `-2` through `-9` plus the base), and the 2026-09-06 candidate is
  status=accepted with its step still unticked
  (`docs/project/plans/2026-09-06-routed-tree-skew-hngh.plan.md`).
  The candidate supply is stale; the alert it answers is obsolete
  until its cause is dispositioned.

## Routing table

| Cause | Disposition route |
|---|---|
| bad-execution | Guardrail or lesson: fold into `docs/project/agent-guardrails.md` via the daily harvest (`hngh-automation/cadence/day/01-lesson-harvest.sh`); kernel-side dispositions follow the closed policy in [autonomous-development-control.md](autonomous-development-control.md). |
| missing-knowledge | Research demand auto-appended to the subject list (`hngh-automation/research-subjects.txt`) — wire designed, not built ([descent.md](descent.md) station 3). |
| missing-design | Research demand gated BEFORE grow admission: the affected grow beat refuses until the design lands. |
| missing-authority | Operator packet: one row in the report ledger naming the exact action, target, and grant needed. The loop waits; it never self-grants. |
| obsolete | Kill or park: close the artifact, mark the row parked, and stop the supply that regenerates it. |

An unknown cause class refuses — same rule as the kernel's disposition
policy ([autonomous-development-control.md](autonomous-development-control.md)):
policy defines the route; a component never improvises one.

---

Back to the [documentation index](../README.md).
