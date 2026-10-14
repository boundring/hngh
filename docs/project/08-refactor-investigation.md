# 08 — Refactor & redesign investigation

Expanded v2.1 investigation, 2026-08-30 (revised after adversarial audit) · part of [README.md](../core/README-architecture.md).
Extends `02-architecture-expanded.md` (its Part 9). Each candidate: problem,
evidence, options, recommendation, estimate
(anchors in [07](07-roadmap-and-estimates.md)),
governance note. None changes code here — recommendations become operator
decisions or future plans.

## R1. Report-ledger strain — split the stream

- **Problem**: machine rows land ~1/30min + alerts: 359 rows / 67,426B as of
  2026-08-30 (grows unboundedly), append-only in the kernel repo, dragged
  through git daily. Bulk is
  machine-consumed noise (config-backup alone ≈ 100 rows/2 days); alerts
  are small and operator-facing.
- **Evidence**: `reports.md` 359 rows / 67,426B as of 2026-08-30 (grows
  unboundedly); `telemetry.db` 40,960B as of 2026-08-30, capture-first
  since `232c5fe` with readers landed 08-29; retention spec
  `ledger-and-records-spec.md` §2.
- **Options**: (a) status quo; (b) split — machine progress rows →
  telemetry.db, alerts stay in git; (c) full telemetry migration.
- **Recommendation**: (b). Alerts are operator-facing and small; progress
  rows are the bulk and machine-consumed.
- **Estimate**: 1 machine session (producer switch behind a flag) + 1
  operator session (spec edit, ceremony).
- **Governance**: kernel docs change = ceremony; routing = normal-risk.

## R2. Plan-authoring gap — the 33h idle

- **Problem**: machine executed an 8-step plan flawlessly, then sat kernel-
  idle 33h: plans are operator-authored; execution is solved, authorship is
  the frontier (report lesson d).
- **Options**: (a) night-agent authors normal-risk plan drafts from the
  Next-necessary list/backlog each night; operator accepts in the morning
  digest; (b) operator authors on cadence; (c) alert→plan routing (R6).
- **Recommendation**: (a) with explicit operator acceptance kept; critical
  class stays parked. Pieces exist: night-agent session, plans/README
  gate-driven acceptance, backlog rows already shaped like plan steps.
- **Estimate**: 1 operator session (authoring prompt) + 1 machine session
  (author→park wiring).
- **Governance**: authorship authority = operator policy grant; mechanism =
  normal-risk.

## R3. STATE.md unbounded growth

- **Problem**: 4.1MB / 37,915 breadcrumb lines as of 2026-08-30 (grows
  unboundedly), minute-tier ticks appending
  thousands/day; retention tiers already specified (raw 7d / rollups 90d /
  curated permanent) but unenforced at the producer.
- **Options**: (a) producer-side rotation (daily STATE files, prune >7d —
  mirrors `02-ledger-prune.sh`); (b) telemetry-store succession; (c) status quo.
- **Recommendation**: (a) now — small diff in `lib/breadcrumbs.sh`; (b) when
  R1 lands (same store, one writer).
- **Estimate**: (a) 1 machine session; (b) rides R1.
- **Governance**: normal-risk; prune-style within retention rules.

## R4. Bash drop-in sprawl

- **Problem**: 28 drop-ins across 8 tiers (as of 2026-08-30) re-copy timeout/lock/breadcrumb
  scaffolding (source of the 08-28 trailing-`\` bug class).
- **Options**: (a) shared runner contract in `lib/` (flock, `timeout -k`,
  breadcrumb, fail-closed; drop-ins shrink to payload); (b) status quo;
  (c) Python rewrite (rejected: churn without behavior gain).
- **Recommendation**: (a) as **absorption** — new drop-ins use the wrapper;
  existing ones convert only when touched. A big-bang rewrite of 28 working
  scripts fails the deletes-more-than-it-adds test.
- **Estimate**: 0.5 machine session for the wrapper.
- **Governance**: normal-risk.

## R5. Presentation contract — kernel vs webapp

- **Problem**: two presentation layers (kernel `src/presentation/render.lisp`
  CLI text; webapp JSON spine) could drift — the reports.md double-header
  class of bug, but for surfaces.
- **Options**: (a) status quo (webapp consumes kernel output as data);
  (b) formalize the spine contract (schema doc + one producer + atomic
  writes, per the 08-30 fix).
- **Recommendation**: (b) narrowly — the spine (`dashboard-readout --json`)
  *is* the contract; document its schema in `docs/design/`, consolidate
  writers, keep the kernel free of webapp concerns. Dependency direction
  stays: webapp outward of kernel, never the reverse.
- **Estimate**: 1 machine session.
- **Governance**: normal-risk; no kernel code change.

## R6. Self-observation closure — alert → plan candidate

- **Problem**: 27+ honest unparsable alerts, zero repairs routed; the F2
  fix needed a human director. Verification without repair is half a
  nervous system.
- **Options**: (a) recurring alert identities (≥3 in window, stable
  identity) become draft plan steps queued for operator acceptance (rides
  R2's mechanism); (b) let the steer leg repair producers directly —
  rejected: script repair is a write path the steer leg must not have.
- **Recommendation**: (a), gated by R2 acceptance flow + escalation caps.
- **Estimate**: 1 machine session after R2.
- **Governance**: normal-risk; operator acceptance per plan unchanged.

## R7. ui-audit → fix loop

- **Problem**: genuine a11y regressions alert but have no repair path; the
  regression breadcrumb feed (plan step 8, landed 08-29) raises them but
  nothing routes them.
- **Recommendation**: fold "fix flagged rule if mechanical (aria-labels,
  titles)" into the next authored plan automatically — rides R2/R6; the
  alert already carries rule identity + example selectors.
- **Estimate**: folded into R2/R6 (≈0.5 session).

## Sequencing

| When | Work | Est. |
|---|---|---|
| Next session (operator) | GLM token decision; R2 policy grant; kernel-src session (omp-bridge refusal cause) | 1 + existing session |
| This week (machine) | R3(a) STATE rotation; R5 spine-contract doc; stage-3 standing-gate wiring | 2-3 machine sessions |
| Next week | R1 ledger split behind flag; R2 authoring prompt; stage 2/3 exit proofs | 3-4 machine + 1 operator |
| Next month | Stage 4 rungs; R6 closure; stage-5 alternation driver | 5-8 machine + 2-3 operator |

## Policy decisions reserved to the operator

1. GLM remote leg activation (token placement) — credential class.
2. Who may author plans (R2) — authorship authority is a policy grant.
3. Ledger stream split (R1) — changes what git permanently records.
4. Any kernel src/Makefile/ASD change — standing autonomy rule.
5. Adding a git remote to hngh-automation (none exists; local-only today).

Cross-links: [06-observability.md](../design/06-observability.md) ·
[07-roadmap-and-estimates.md](07-roadmap-and-estimates.md) ·
`docs/project/backlog.md` (admission-shaping rows).
