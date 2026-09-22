# 2026-09-22 — Federal-branches occupancy, slice 1: bailiff wire, executive guard, bead intake

Status: landed. Plan: `docs/project/plans/2026-09-22-federal-branches-occupancy.plan.md`
(accepted 2026-09-22). Charter: `docs/project/plans/2026-09-20-federal-charter.plan.md`.

## Why

The charter's three branches were accepted but not yet occupied. The gap
audit (2026-09-22) found one missing officer above all: the bailiff.
`ng/watch.py` emitted audit findings that nobody consumed, so the
kernel-gate-red-halted-nothing crisis class could repeat. This slice
lands the bailiff, a first executive guard, and the charter's
event-driven bead intake.

## What landed

### Bailiff wire (step 1)

- `automation/ng/watch.py` gained a read-only `--bailiff` CLI: runs the
  audit, prints `finding {check} {version}` lines to stderr, and a
  verdict — `bailiff: halt` (exit 1) or `bailiff: clean` (exit 0) — as
  the last stdout line.
- `automation/lib/bailiff.sh` `bailiff_check()` mirrors that verdict:
  halt → `bailiff-halt` breadcrumb + rc 1; fault (audit itself broke) →
  `bailiff-fault` crumb + rc 0 (fails OPEN deliberately: the bailiff is
  a belt, not the system of record; a broken bailiff must not freeze the
  whole cadence).
- `automation/jobs/cadence-tick.sh` sources it for every tier:
  `bailiff_check || exit 0`. A halt means the tick skips its drop-ins
  (skip-with-crumb, tick stays rc 0 so the timer stays healthy).
- Ledger seam: `HNGH_LEDGER_DIR` env redirects the whole ledger surface
  (hermetic tests, test seeding).

### Stale-verdict scope fix

`watch.py` `PENDING_STALE_KINDS` narrowed to `("triage.verdict",)`. The
old scope flagged ANY event >50 versions old in the last-200 window —
which the new hourly beat would hit within days and permanently trip the
bailiff on its own history. Judgment records are history; deferred work
lives in cadence STATE, not the ledger.

### Executive guard (step 2)

`automation/lib/launch-jcode.sh` runs `ng/jcode_guard.py` over
`$JCODE_PLAN_JSON` before any spawn: node cap (default 64), depth cap
(default 8), cycle detection. Violation or unreadable graph → rc 75,
no spawn, no spend.

### Bead intake (step 3)

- `automation/cadence/hour/25-bead-beat.sh`: hour tier now polls beads
  directly via `ng/cadence.py` (beat): open beads → Jev triage → close /
  slice / defer / escalate, per the charter's legislative intake.
- `automation/ng/surface_escalations.py`: every `escalation.filed`
  lands on the operator surface (`scripts/report-queue`) in the beat
  that files it — identity `escalation:<bead>:<reason>`, 7-day window,
  re-fires bump the same row. Fail closed: malformed input files
  nothing.
- Attempt cap + halt: `_handle` accumulates attempts in STATE; at cap a
  bead gets one final `attempts-exhausted` escalation then leaves the
  loop (`STATE.exhausted`) until it closes (purged when it leaves the
  open set). Escalated beads no longer rediscover fresh every beat.
- `automation/ng/ledger/` is runtime judgment state: gitignored.
- Self-check: `python3 automation/ng/cadence.py --dry-run` →
  `cadence self-check ok` (includes the attempt-cap/exhaustion/purge
  case).

## Escalation SLA + halt conditions (escalation-sla rule)

- SLA: an escalation reaches `docs/project/reports.md` in the beat that
  files it; row expires after 7 days of silence; re-fires bump the same
  row. Routed ≠ resolved.
- Halt: per-bead attempt cap → one final `attempts-exhausted`
  escalation → bead dropped from the loop permanently until closed.

## Verification

- `automation/ng/test-bailiff.py`: 16 assertions (verdict mirroring,
  stale fixture, fault fail-open, tick source contract, live hour-tier
  smoke with seeded ledger — no drop-ins ran).
- `automation/tests/test-jcode-spawn-guard.py`: 14 cases (cap, depth,
  cycle, no-plan no-op, rc 75).
- `automation/ng/test-dispatch-gate.py` green; `cadence.py --dry-run`
  green.
- Full automation gate: ALL PASS + lint clean.
- Kernel gate: green (untouched surface).
- Live smoke: beat polled 5 open beads, Jev triaged (close/slice
  verdicts), events landed in `automation/ng/ledger/events.jsonl`,
  bailiff clean.

## Notes

- Jev grammar rejects some verdict shapes (reason phrases in the refs
  field); those beads re-triage hourly — idempotent by design.
- The bailiff halt is per-tier-skip, not process kill: the timer stays
  healthy and the crumb records why. Recovery is automatic once the
  ledger returns to clean.
