# alert-to-work routing patterns: closing the self-observation loop

Status: crystallized 2026-08-30 from research line `alert-to-work-routing-patterns-closing-the-self-observation-loop`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-alert-to-work-routing-patterns-closing-the-self-observation-loop.md.
Grounded rewrite 2026-08-30: the original crystallization framed Hngh
as a Linux kernel module (Netlink families, sysfs exposure, ring
buffers, kernel/user daemons). None of that exists here — Hngh is a
Common Lisp kernel plus no-daemon shell automation, and its alert
surface is an append-only report ledger. That mechanics layer is the
named foldback anti-pattern and is discarded; the loop-closing
conclusion survives and is restated in Hngh's actual shape.

## Conclusion (kept, reframed to this repo)

The self-observation loop is open in exactly one place: alerts are
generated and deduplicated, but nothing records whether the work they
named was ever scheduled, done, or was noise. The loop closes not by
adding a transport but by giving every alert class a **parseable
plan-step candidate** — because in this system the only thing that
turns observation into work is an accepted plan (foldback lesson 2:
alerts close their own loop only through plans; every repair in the
33h window originated in a plan step or an operator session, never
from the alert itself).

The routing shape, using only what exists:

- **Alert emission** — jobs and ticks append `alert` rows to the
  report ledger (`scripts/report-queue add alert …`), each row
  carrying a kind, an id, and a first line naming the producer
  (oversight loop-signal, gate-check, tree-skew, agent-stall,
  ceremony-temp, review findings, slow-unit).
- **Candidate emission** — a routing table maps each alert class to a
  plan-step candidate: title, verification command, risk class
  (normal → plan step; critical-class → parked with operator-facing
  alert, per the plan contract). The candidate lands in
  `docs/project/plans/` as a proposed plan or an appended step on an
  open plan — the two authoring surfaces the machine already has.
- **Outcome tracking** — the plan lifecycle already records the
  outcome: a step's checkbox tick and the front-matter status
  transition (proposed → accepted → executing → executed/parked) plus
  the reports rows the execution writes. Alert → step → tick/rows =
  closed loop; no new state store is needed at check-in scale
  (`docs/project/plans/README.md` defines the machine-checkable
  states).

## Findings (grounded rewrite)

- **F1 — alerts are honest but terminal.** The 2026-08-28→30 window's
  alert classes (stale-store ceremony-temp, review P0/P1, tree-skew,
  agent-stall, unparsable readout.json, doc-suite checker rc=1,
  remote-posture degraded, budget digests) were accurate; every one of
  their fixes still originated in a plan step or an operator session.
  The ledger records the signal; nothing routes it into the plan
  queue.
- **F2 — the flap-suppression layer is already the dedup layer.**
  Oversight alerts arrive flap-suppressed (roadmap stage 1: alerts are
  "flap-suppressed") and report-queue already has identity+window
  dedup with escalation caps (backlog row). So the loop does not need
  new suppression machinery — a routed candidate only needs to exist
  once per alert identity, which the existing dedup already
  approximates.
- **F3 — candidate authoring is the missing edge, and it is the same
  gap as plan authoring itself.** The machine cannot author plans
  (foldback lesson 1 / suite doc 08 R2); a routing table that emits
  *draft plan steps* (title + verification + risk class as parseable
  text) feeds the night-agent plan-authoring row rather than replacing
  it: routing proposes, a plan-shaped surface accepts.

## Recommendation (the designed mapping, docs-only)

Map alert classes actually filed in `docs/project/reports.md` to
candidate step shapes:

| alert class (observed) | candidate step shape | risk |
|---|---|---|
| gate-red (kernel or automation) | re-run gate, capture failing check, fix-or-park step | normal |
| tree-skew dirty-tree | whitelist check + handoff/commit of stalled edit | normal |
| agent-stall / loop-signal | roguelike die+replace: end session, handoff brief, respawn step | normal |
| ceremony-temp / store alerts | re-run ceremony fresh-store step (known recovery) | normal |
| review P0/P1 findings | docs/automation fix step with named verification | normal |
| unparsable readout.json | feed-regen re-read step (fix already landed as precedent) | normal |
| remote-posture degraded / budget idle | operator-facing alert row; PARKS (operator-only legs) | critical |

Each candidate step carries its own verification, so a plan built from
the table is auto-acceptable per the plan contract when the gates are
green. Implementation of this table as automation-side routing (a
read-only tick that drafts the candidates) is follow-on work only if a
plan asks for it — it needs no kernel changes.

## Open threads

- Where draft candidates live: a section in `docs/project/plans/README.md`
  vs a queue-ledger column (design decision for the routing DESIGN beat).
- Escalation caps interplay: a routed alert must not re-fire while its
  plan step is open (dedup window vs plan lifecycle).

## Grounding

Verified paths read in this repo while rewriting (2026-08-30):

- `docs/project/reports.md` — the live alert ledger (gate-red,
  tree-skew, agent-stall, loop-signal, slow-unit, ceremony-temp,
  review, remote-posture, budget-digest rows all observable there)
- `docs/project/roadmap.md` — stage 1 self-watch (flap-suppressed
  oversight alerts), stage 3 self-supervision framing
- `docs/project/backlog.md` — "Alert → plan-candidate routing" and
  "Night-agent plan authoring" rows; report-queue escalation caps row
- `docs/records/2026-08-30-lessons-and-foldback.md` — lesson 2
  (alerts close their own loop only through plans) and §1's failure
  classes
- `docs/project/plans/README.md` — the plan contract the candidates
  must parse into (status lifecycle, risk classes, auto-acceptance)
- `hngh-automation/jobs/oversight-tick.sh` and
  `hngh-automation/scripts/report-queue` — the producers of the alert
  rows the table routes (verified present; identities observed in
  reports.md)

Discarded as ungrounded (the original crystallization's mechanics):
kernel modules, Netlink generic families, sysfs/tracepoint exposure,
userspace daemons. Hngh has no kernel module; its alert surface is the
report ledger.
