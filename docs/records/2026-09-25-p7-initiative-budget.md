# Refoundation P7 — initiative budget (route expiry, filing budget, loop re-queue)

Date: 2026-09-25. Plan: hngh refoundation pass, phase P7.
Principle: escalate-by-default closes open loops (docs/project/decisions.md
entry template; loop recognition rubric records/2026-08-26-loop-recognition.md).
Adversarial: budgets can suppress a real second signal — mitigated by
question-rows and crumbs (the signal is always recorded, never dropped).

## What changed

- `scripts/router-tick.py` — re-route expiry: chain members mint with
  `<!-- attempt: n -->` + `<!-- expires: <ISO> -->` headers (7d).
  `chain_expired_close()` retires members past their expires stamp with
  `status=expired` + `cause: route-expiry`; a chain that falls below the
  re-route bound as a result ends its lane with ONE operator row
  (`route-expiry:<identity>`, window 7d) — no further re-routes, no park
  alerts. `chain_live_count()` liveness fix: a bare TTL corpse (no expires
  stamp, no route-expiry cause) still binds the re-route bound, so TTL
  expiry alone can never force a fresh route every run; only a stamped
  closure frees the lane. The expired-refire escalation branch
  (`router:escalated:<identity>`, window 0) is preserved verbatim.
  Route mints respect the filing budget: over budget → one progress row
  `filing-budget:routed:<identity>` (window 1d), no mint.
  Env seams: `HNGH_PLANS`, `HNGH_FILING_STATE`.
- `lib/filing_budget.py` (NEW) — one shared counter,
  `state/filing-budget.tsv` rows `<family>:<cause-token>\t<UTC-date>`,
  flock, append-only. `allow(family, cause)`: one filing per family:token
  per UTC day. CLI for shell seams (rc 0 allow / rc 1 deny, fail-open).
  Families: fail | patrol | synth | followon | routed.
- `lib/causes.sh` `append_research_subject` — new-mint path: disposition-echo
  check first (filing-about-filing → crumb, never a row), then budget
  (`fail` family; deny → crumb `research-subject-demoted`, no append).
  P6 slug-matches to existing open lines are exempt.
- `jobs/patrol.py` `queue_repeat_subjects` — new-mint path only:
  budget deny (`patrol` family) → crumb, rid still queued, no row.
- `cadence/hour/33-research-beat.sh` — synthesizer accepted-mint and
  `ensure_lines` over budget (`synth` family) → `question-<id>` row (P6
  shape), never a new line/beat. Disposition echoes skipped with breadcrumb.
- `jobs/agent-supervision.py` — loop re-queue: a stuck tick (loop/err
  signature) steers once with `cause=repeat-loop` + one progress row
  `loop-requeue:<id>` (window 1d, rubric-cited), a second consecutive
  stuck tick dies with `cause=repeat-loop`; recovery resets and files one
  flap row. Stuck sessions stay exempt from the plain miss machine.

## Verification

- `tests/test-initiative-budget.sh` (NEW, 31 checks): router expiry fixture
  (3 stamped members flip to expired, exactly one route-expiry row, no park
  row; over-budget deferral; fresh mint stamps attempt:1 + future expires),
  budget allow/deny/next-day + normalization, causes.sh mint/deny/echo trio,
  supervision steer→die→recovered sequence.
- `tests/test-router-feed.py`: sandboxed `HNGH_FILING_STATE` (was consuming
  the real state file); bound-park contract re-pinned (TTL corpses bind).
- Full `make test` green; root `make test` green.
