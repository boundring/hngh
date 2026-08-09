# Owner-facing decision briefs — format + review pass (card 115)

One page. Design-first. Feeds 116 (dashboard render of owner/inbox.md).

## 1. Problem

A lone agent escalates to owner/inbox.md in prose. The ask can be
under-scoped, unprioritized, inscrutable; no dashboard surfaces it;
the owner holds full context manually. 107A sat unread longer than
expected — the owner's words: the demand is inscrutable, decisions
should be passed around for more than one agent to consider.

## 2. The bounded brief (the format)

Every owner-facing decision lands as a BOUNDED BRIEF, not prose.
Template — five fields, hard caps:

```
DECISION: <one sentence: what the owner must choose>
CHOICES:
  A. <option> — <cost/unblock in one clause> (<tradeoff>)
  B. <option> — <cost/unblock in one clause> (<tradeoff>)
  C. <option> — <cost/unblock in one clause> (<tradeoff>)
SIZE: S|M|L   URGENCY: <now|today|this week>   BLOCKS: <seats/cards>
REVIEWED: <seat> ACK <stance>; <seat> ACK <stance>
DEADLINE: <ISO or none>
IF NO DECISION: <fail-closed default — what happens, who it hurts>
```

- DECISION ≤ 1 sentence. CHOICES ≤ 3. Each option: cost/unblock +
  one tradeoff clause. No paragraph prose.
- SIZE = estimated owner effort to decide (S ≤ 2 min, M ≤ 10 min,
  L = needs discussion). URGENCY drives the owner-inbox render order.
  BLOCKS names the seats/cards waiting — the owner sees blast radius
  at a glance.
- IF NO DECISION is mandatory: a decision that silently expires is
  the failure class we are killing. Default is fail-closed (do
  nothing = do the safe thing, not the nothing).

## 3. The review pass (>= 2 seats before landing)

- The DRAFTING seat fills the template and sends it to a SIBLING's
  lane for review — never lands directly.
- The REVIEWER checks: (1) decision is one sentence and real (not a
  status report), (2) choice set is honest — no strawman option,
  tradeoffs stated, (3) size/urgency/blocks are truthful, (4)
  IF-NO-DECISION is present and fail-closed, (5) reviewer's own
  stance is appended to REVIEWED.
- Two ACKs required before the brief lands in owner/inbox.md (the
  owner's >= 2 agents requirement). A reviewer may BLOCK (format
  violation, strawman choice, missing fail-closed) — the draft goes
  back, it does not land.
- REVIEWED line carries the stances so the owner sees WHO disagreed
  and why, not just that two seats signed it.
- Sibling review is automatic (no owner approval needed to review);
  the owner gate (open question) is whether LANDING requires owner
  ack vs landing-with-render — see card open question.

## 4. Interim (until 116 renders it)

Card 107A-type escalations follow the format NOW, before any code:
both seats use the template in owner/inbox.md entries starting
immediately. The file stays append-only; each entry is one brief.
The owner-inbox dashboard view (116) renders these fields as cards.

## 5. Acceptance

- Template documented (this page), used by both seats for every new
  owner/inbox.md escalation from today.
- Every escalation in owner/inbox.md carries the 5-field shape +
  REVIEWED with >= 2 ACKs.
- One migration pass: the standing 107A escalation is re-issued in
  the template with both seats' stances (they already agree).

## Open question (owner)

Explicit approval gate on the review pass (briefs land only after
owner ack) vs sibling-review-automatic (land, render, owner decides
at leisure)? Recommendation: sibling-review-automatic for S, owner-
ack for M/L — keeps small decisions moving, large ones human-gated.
