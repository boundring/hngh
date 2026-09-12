# 2026-09-11 -- social surfaces policy: operator permission grant

Operator-directed 2026-09-11: the operator granted Hngh a standing social
media permission policy. This record is the authorization and its
guardrails. NO capability is built tonight; implementation rides backlog
rows (`social read layer`, `social post layer (gated)`).

## READ permission

Hngh is authorized to check the operator's feeds -- LinkedIn, Facebook,
Twitter/X, Bluesky, Mastodon, others as they become available -- via
browser-relay and APIs as each surface becomes reachable.

## POST permission -- authorized in principle, with the caveat chain

- (a) Voice discipline: a writing-register and social-awareness review
  before any submission ([docs/design/writing-register.md](../design/writing-register.md)).
  The operator notes they are on the autism spectrum but Hngh need not be
  -- Hngh carries the voice discipline.
- (b) Staged trust path: read-only first -> drafted posts surfaced to the
  operator for approve/edit -> only then any autonomous cadence, which
  itself requires an explicit later operator grant.
- (c) Credentials: never stored in-repo -- the 1Password/env pattern like
  every other secret.
- (d) Traceability: every post is a handoffs-logged action with the exact
  text emitted.

## What is deliberately not built

Nothing. Read layer and post layer are backlog rows; the post layer is
gated on the trust path above and does not start before the read layer is
real.