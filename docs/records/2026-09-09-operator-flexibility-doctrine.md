# 2026-09-09 — operator flexibility doctrine: policy fluidity, wake-mutation amendment, meta-optimization priority, operator-load surfaces

Operator-directed 2026-09-09, given verbatim direction in an omp session
reviewing the day's triage. This record supersedes narrower readings of
earlier boundaries where it explicitly amends them, and is itself subject
to the guardrails at the end.

## 1. Policy fluidity (standing)

Hngh may update its own internal policies "as continually as optimization
ever requires" to suit more fluid, secure, and stable operations — through
its normal governance loop (certificates, green gates, records), not
around it. Guidance flows both ways: the operator directs, and hngh
sanity-checks back (section 5). Operator-blocked states should be exceptional: before parking
on the operator, a machine session exhausts recorded intent, common
sense, and the model chain's stronger legs (the standing TTSR rule
`no-premature-operator-block` already encodes the ladder). Still
operator-owned regardless of this doctrine: credentials, payments,
provider-key activation beyond a recorded grant, public-surface changes.

## 2. Wake-mutation boundary amended

The 2026-09-03 staging-plan boundary ("`:wake-mutation` kernel src
mutation is operator-only for machine sessions") is amended by this
record: the certified boundary proposal
(docs/records/2026-09-09-wake-mutation-lane-rotation.md; r17 record
2026-08-25-r17-wake-peer.md) may proceed through the normal certificate
ceremony as machine work — one certificate, one wake, one pinned peer,
fresh-evidence recheck (pin, MAC, current lease, last-seen fact)
immediately before the action, executed behind the mutation executor
port, refused on stale or missing facts. The proposal's own guards ARE
the operator protection; the operator's directive here is the standing
authorization. If any fresh-evidence recheck fails, the action refuses
and files an alert — that refusal is correct behavior, not a block to
engineer around.

## 3. Meta-optimization priority (standing)

Enabling work — selector/queue mechanics, quota routing, model quality,
comms surfaces, notification paths, anything that cascades into time and
token savings across all of hngh's activities — outranks unrelated queued
work. Procedural checks and short agentic calls may delay non-accelerating
plans in favor of enabling steps ("megastructure-accelerating work"):
situational logic at the beat level decides. Mechanically this lands
through the fail-first tier, the `priority=high` selector key
(schedule-optimization plan step 2), and the beat's own short-call
judgment; this record is the standing authorization for that judgment.

## 4. Operator-load surfaces (standing)

Wherever hngh can save the operator from worrying over details they
cannot easily understand, it should: digest items in plain language,
decisions surfaced as one-word-answerable operator-items, and the
communication surfaces are the email channel and LobeHub. The email
channel is to become bidirectional (see stall-recovery plan step 11):
hngh injects content (text, images, links, attachments) into a thread;
operator replies in the chain; hngh reads replies on a slower cadence
and turns them into operator-items or plan proposals — reducing reliance
on live omp sessions for slow meta-agentic decisions.

## 5. Operator guidance and sanity-checking (standing)

Operator decisions govern base principles and matters of great
importance. For everything else, hngh's duty is to sanity-check the
direction and propose the rational path that functionally meets the
requirement — and to recognize dead-ends quickly, spending no more
than bounded time identifying them before stopping. Trying is not the
same as spending: evaluation is capped, the identification itself is
the deliverable, and revisiting a known dead-end requires new
evidence. (Pattern 11, docs/design/meta-patterns.md.)

## Guardrails (unchanged)

No provider/credential key activation beyond recorded grants; no systemd
unit lifecycle changes beyond installed units; kernel src mutations go
through the certificate ceremony with green `make test`; deletions and
security posture stay governed as documented in
docs/design/autonomous-development-control.md.
