# 2026-09-27 — Dashboard situation-specific operator actions

Verified facts

- The broadsheet operator desk previously offered exactly two choices per
  item (handle/dismiss); `/report-queue/mark-read` and `/flag` existed
  server-side but were not surfaced (`scripts/newspaper-compose.py`
  operator_articles; `automation/dashboard/broadsheet-view.js:416`
  ALLOWED_ENDPOINTS).
- Compose now derives, per open operator item, an ordered keyword taxonomy
  class (real-regression -> operator-decision -> transient-heartbeat ->
  stale-superseded -> automation-debt default) and emits a per-class
  primary + secondary choice ahead of the always-present handle/dismiss.
- Six operator verbs are live end to end:
  `/operator-item/{handle,dismiss,park,expire,suppress,acknowledge}`.
  park requires a non-blank note (<=200 chars); acknowledge takes an
  optional note; all verbs reject dunder ids with 400 (durable INT-28
  guard, previously detection-only); ledger writes stay idempotent and
  fail closed before any write.
- Article dedupe: key = first two pipe fields of the first line
  (stamp-stripped, normalized); freshest member represents the group and
  carries the payload id; groups render an xN occurrences badge. Live
  smoke on 2026-09-27: 13 operator cards -> 8; the curator-beat flood
  collapsed to one card at occurrences=15 with a template narrative.
- Narrative: optional article field, 2-4 template sentences composed when
  a group re-fired (occurrences > 1) or urgency keywords
  (alert/escalation/regression/routed) match; no LLM call in compose.
- View: whitelist extended to exactly the six endpoints; park/acknowledge
  prompt for a note; a whitelist-parity test pins view == emitted
  endpoints.

Decisions

- expire/suppress are dismiss-variants that record the reason in the
  ledger row + body handoff: scripts/report-queue has no expire/suppress
  verbs, and adding ledger machinery for a UI verb was rejected.
- Dedupe key is the first-line job|kind prefix only; genuinely different
  jobs/kinds stay distinct (pinned by test).
- Payload carries the single freshest group id. Bounded unknown: detail
  tails under one prefix keep distinct ids; suppressing the group
  representative leaves sibling ids to resurface next edition (the xN
  badge shows group size). Widening payload to an ids array is a contract
  change, not taken today.

Verification

- Red-first confirmed: compose 9F+2E, lifecycle 6F before implementation.
- `make test` green on the final tree (229s); compose suite 26 OK,
  lifecycle suite 25 OK.
- Guidance row `orchestrator-dispositions-20260927` (report c99a7a21)
  files the follow-ups: ledger-sanity census before re-escalation,
  introspect-debug residue cleanup, slow-unit profiling before further
  compose load, INT-9 choice-previews probe remains crowd-dependent by
  design.
