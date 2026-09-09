# 2026-09-09 — stage-4 governed package upgrade runbook design

## Status
accepted. Evidence reviewed 2026-09-09T23:00Z. Verdict: operator-supervised execution.

## Stage 4 exit criterion (from roadmap)

Stage 4: "CachyOS package inventory feed (landed as system-ops v1) grows governed update lanes; config-backup generalizes into the config-manager."

## Runbook outline

### Prerequisites
1. System package inventory feed (system-ops v1, landed)
2. Certificate binding the exact package list (via certificate ceremony)
3. Fresh-evidence recheck immediately before mutation (system-ops v1 probe)

### Steps
1. **Probe inventory** — run system-ops v1 to capture current package state
2. **Bind certificate** — use certificate ceremony to bind the exact package list
3. **Fresh evidence** — re-run system-ops v1 probe immediately before mutation
4. **Operator supervision gate** — operator issues the allow/deny
5. **Mutation** — apply package updates (if operator allows)
6. **Rollback/reversibility** — package downgrade path documented

### Operator supervision boundary
- The operator must issue the allow/deny gate (step 4)
- No automated execution past step 4 without operator instruction
- The mutation itself is a critical-class operation (system package updates)

### Rollback/reversibility
- Package downgrade path: `pacman -U <package-file>` for each updated package
- Config backup: system-ops v1 already captures config state pre-update
- Reversibility: config-backup generalizes into config-manager (stage 4.5)

## Operator-supervised boundary

The execution is operator-supervised. The runbook is design-only; the actual upgrade run is parked for operator supervision.

## Parked execution note

Execution is parked. The certificate ceremony can bind the package list, but the actual package update requires operator supervision (critical-class system operation).

## Kernel gate

`make test` passes (2855 checks, 2026-09-09T23:00Z).
