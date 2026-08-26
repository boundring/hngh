# Architecture index — 2026-08-26

**Scope:** documentation-only. Added the single hub that maps the
system-harness intent onto its concrete homes, and reconciled the
activity-cadence timing-window note. No source, no queue/backlog edit.

## What landed

- **`docs/architecture-index.md`** — the index of the shared corpus.
  Built on top of the unchanged `docs/architecture.md` charter, it maps:
  - system-harness rungs **A–F** via
    `docs/project/system-harness-roadmap.md`,
  - the queue rotation handles (TSV ids) in `docs/project/queue.md`,
  - the proposal headings in `docs/project/backlog.md`,
  - the promotion rungs 11–18 already landed (roadmap `## Now`),
  - the dated records in `docs/records/README.md`,
  - the 8 autonomy-continuum directives from the roadmap `## Next`
    rung 2 (each with its queue id, backlog heading, and record), plus
    the two operator directives outside that frontier
    (`webapp-dashboard`, `self-optimization-continuum`),
  - a legend (queue id = rotation handle; backlog heading = proposal
    prose; A–F harness rungs vs numbered promotion rungs).
- **`docs/project/activity-matrix.md`** — reconciled (additive, no
  overwrite of the sibling draft): verified the 10 activity rows against
  the backlog `activity-cadence` list and added a `## Timing-window
  evaluation` section (event-fire/1m–5m/10m+/hourly+/agentic-gated
  placement) that was not already present. This file is sibling-owned
  and left uncommitted for the owning lane's own commit.

## Evidence

- `make test` — 2777 checks passed (full Lisp + reader-guard suite).
- `git status` verified before the ceremony; the manifest below is
  deliberately narrow (only the files this slice owns) so no sibling
  lane's uncommitted changes are captured.

## Remaining unknowns

- `activity-matrix.md`, `backlog.md`, `ui-grades.md`, `reports.md`,
  `scripts/dashboard-tui`, the `evolve-dashboard-style` slice, and
  `docs/records/2026-08-26-*` (`evolve-dashboard-style`,
  `oversight-tick`) are uncommitted by this slice — they belong to
  sibling lanes and will land through their own commits.
- The five harness rungs `resource-pool-view`, `config-manager`,
  `security-manager`, `notify-agent`, `ci-governance-gate` are queued
  in backlog but not yet queue.tsv rows; that is captured as the known
  backfill step, not a defect.