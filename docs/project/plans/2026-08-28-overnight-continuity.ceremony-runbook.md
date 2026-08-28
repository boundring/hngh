# Ceremony runbook — 2026-08-28 overnight continuity wave

The 08:30Z delegated session verified every step of the plan and staged
all ceremony candidates in the working tree; only the certificate loop
remained when its 1800s timeout hit. This runbook is the handoff.
Follow skill `hngh-dogfood-commit-ceremony` verbatim; fail closed.

## Candidate paths (sorted, as required by real-cert manuscript)

    CHANGELOG.md
    docs/design/subsystem-anatomy.md
    docs/design/ui-evolve/current-overlay.json
    docs/project/heartbeat/bridge-operator-host.slice
    docs/project/plans/2026-08-28-overnight-continuity.ceremony-runbook.md
    docs/project/plans/2026-08-28-overnight-continuity.plan.md
    docs/project/reports.md
    docs/project/ui-grades.md
    docs/records/2026-08-28-automation-advancement.md
    docs/research/2026-08-28-log-presentation-patterns.md
    docs/research/2026-08-28-session-cost-display.md
    docs/research/2026-08-28-tech-tree-research-ux.md
    docs/research/2026-08-28-telemetry-schema-exemplars.md

Excluded on purpose: `.omp/` (harness settings, not project docs).
Docs-only candidate — kernel `src/`, `tests/`, `Makefile`, `hngh.asd`
untouched, per the session's autonomy rule.

## What each candidate carries

- `subsystem-anatomy.md` — new "Continuous operation" section (overnight
  loop selector, plan-ledger lifecycle, research-line lifecycle, budgeted
  remote GLM leg, telemetry store) + 4 stale-row fixes.
- `automation-advancement.md` — framing correction: operator-authored /
  operator-accepted plans, machine-executed and machine-landed; ceremony
  row updated to autonomous overnight firing.
- `CHANGELOG.md` — 2026-08-28 entry corrected (operator acceptance) +
  ceremony-landing sentence appended.
- `*.plan.md` — all verify steps checked off with evidence annotations;
  ceremony box left unchecked for this loop to close.
- `docs/research/*` — four crystallized research docs from the day-tier
  beats (gantt-legibility landed earlier).
- `reports.md` / `ui-grades.md` / `current-overlay.json` /
  `bridge-operator-host.slice` — machine-maintained ledger appends from
  the day's cadence jobs.

## Loop specifics beyond the skill

- `propose` requires all 15 keys (see `src/main.lisp:1005-1010`):
  class problem outcome purpose caller input-contract output-contract
  failure-contract declared-capabilities capability-diff source-manifest
  risk-note dependency evidence-trigger evidence-requirements.
- `evidence-requirements=PRINCIPLE:KIND:FINGERPRINTS` — one per
  principle, 10 principles (closed-authority least-authority
  dependency-direction fail-closed evidence-before-flag atomic-mutation
  reversibility no-hidden-execution cost-and-route-discipline
  source-grounding); KIND=claim-proof; quote values with spaces.
- `source-manifest=PATH=HASH:ROLE` per candidate file; hashes are
  gathered live by `issue-cert` (verify-candidate.py --manifest +
  per-file sha256) — compute them at cert time, after any last edits.
- After the commit lands: check the final plan checkbox and amend the
  record doc if needed via the SAME loop, then push
  (origin git@github.com:boundring/hngh.git). `make test` must be green
  before push.
