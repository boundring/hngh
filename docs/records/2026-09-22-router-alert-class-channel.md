# 2026-09-22 — Router alert class channel

Status: landed. Plan:
`docs/project/plans/2026-09-22-router-alert-class-channel.plan.md`
(feed class enforcement + report-queue `--class`, 4 steps). Scope:
repo-root `scripts/` (ceremony lane), `automation/` (free-commit
surface). Kernel `src/` untouched.

## Context

Incident: parked **critical-class** operator alert
`mem-caps-dropin:hngh-dashboard` (reports.md alert `afd8588b`,
2026-09-22T14:57:08Z — systemd resource caps for the dashboard unit)
was router-routed into a normal-risk plan candidate
(`docs/project/plans/2026-09-22-routed-mem-caps-dropin-hngh-dashboard.plan.md`)
and auto-accepted at 16:03:32Z. Operator review of reviews (supportive
+ adversarial, 2026-09-22) settled the scope: "Full revised A" — a
first-line word scan in the feed plus a durable class channel, over
report-queue/argv plumbing, with a parked item shaping the review
(smell warning: the operator item is a smelly, floor-lowered ask —
require machine-readable clarity in the filing contract).

## Landed slices

1. **report-queue `--class`** (ceremony lane):
   `scripts/report-queue` gains `--class critical|normal` (argparse
   choices, bad value → rc 2) passed to `add()` as 6th arg. Only
   `critical` stores a durable meta (`- **class:** critical` in the
   body, via `body_class(ts,kind,rid)` reader); `normal` and legacy
   filings store none, so absence stays the default. A critical re-fire
   on a live non-critical row never silently bumps: it files a distinct
   `class-upgrade:<identity>` row so escalation is visible. Failing
   tests written first:
   `tests/scripts/test-report-queue.py` class `ReportQueueClassMeta`
   (5 tests, kernel-surface file rides the ceremony commit).
2. **Feed enforcement** (`automation/cadence/hour/10-router-feed.sh`,
   commit `a6e07f7d`): reserved identity prefixes gained
   `class-upgrade:`; any row whose body carries `- **class:** critical`
   is excluded from routing; belt: identity-free critical-word scan on
   the row's first line. `seen` is only marked after all exclusions
   pass.
3. **Plumbing** (`automation/lib/notify-email.sh` +
   `automation/lib/operator-item.sh`, same commit): `alert_row`
   signature `(identity window subject text [class])`; `operator_item`
   passes its optional 3rd arg through (`${3:-}`) — a filer of a
   critical item can now express its class machine-readably.
4. **Disposition**: routed mem-caps candidate parked via
   `automation/scripts/plan-dispose.py --action park --cause obsolete`
   (superseded by `docs/records/2026-09-22-ram-guardrails-landing.md`
   operator-directed application of step 5a).

## Verification

- `python3 tests/scripts/test-report-queue.py` → 36 OK (31 + 5 class).
- `python3 automation/tests/test-router-feed.py` → 8 OK (3 new class
  tests: critical rows never route, first-line critical word excluded,
  class-upgrade identity excluded).
- `python3 automation/tests/test-cap-block-operator-item.py` → 3 OK
  (operator_item `critical` reaches the queue body).
- Kernel gate + automation gate: see "Both gates" below.

## Notes

- Class semantics deliberately one-directional: `--class critical` is
  additive metadata + a routing exclusion; nothing downgrades a row.
  Rows carry class only when critical — normal stays the unwritten
  default, so legacy rows need no migration.
- The `class-upgrade:` identity is itself in the feed's reserved-prefix
  tuple: the upgrade row is operator-visible (queue) but never routes.
- Lesson (test honesty): a bump in report-queue folds
  `- {ts} occurrence` into the body plus a `×N` marker in the ledger
  row cell — asserting the invented literal "re-occurred" passed
  vacuously until the wording was checked against `bump_row`.
