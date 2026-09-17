# 2026-09-16 — identity-seam reconciliation: the Fixture authorship window

## Defect

A placeholder `[user]` block (`name=Fixture`, `email=fixture@example.invalid`)
sat in this repo's `.git/config` from 2026-09-13 00:04:04 -0400 until
2026-09-16 19:25 -0400. Every commit made by any session in that window
without an explicit per-command identity carried the anonymous author.

## Canonical census (method + ground truth)

Method: `git log --format=%ae ba6b3905^..30556e67` (inclusive window),
cross-checked with `git log ba6b3905..30556e67` plus the boundary commit.

- Window: `ba6b3905` (2026-09-13T00:04:04-04:00, first Fixture commit) ..
  `30556e67` (2026-09-16T15:22:25-04:00)
- **566** commits authored `fixture@example.invalid`
- **2** commits authored `automation@hngh.local` (`e916af9e`, `8e376ff2`,
  the only per-command `-c` identity commits in the window)
- Total: **568**

Count reconciliation: commit `16dae2eb`'s message says "564"; the
supportive-4 artifact says "567". Both are wrong; this record is canonical.
(The 564 figure was computed before the window's final commits landed;
the 567 figure used an exclusive-window `git log` that drops the boundary
commit. Use the method above.)

## Remediation landed (2026-09-16, operator-approved)

1. Local `.git/config` identity set to `hngh-machine
   <automation@hngh.local>` (the convention already established by
   `e916af9e`/`8e376ff2`).
2. `automation/jobs/config-backup.sh` — the one committed auto-committer —
   now pins identity per invocation (`-c user.name` / `-c user.email`),
   so attribution never depends on ambient config state.
   Commit `16dae2eb`; `make test` 2931 checks green; CI green.
3. Post-fix verification: all 15 commits `16dae2eb..HEAD` correctly
   authored `hngh-machine`; zero post-fix Fixture commits.

## No-rewrite decision

The 566 misauthored commits keep their recorded authors. Rewriting would
churn every patch-id the loop-history guard pins (its exemption table
carries the 2026-09-13 fixture pair by design), for metadata whose
security value is nil — git authorship is trivially forgeable and is not
an authorization surface. The certificate system (paths + content hashes
+ ten principles) verified every mutation in the window; the exposure is
attribution/traceability only. This record is the correction of record.

## Remaining unpinned committers (open)

`config-backup.sh` is pinned, but five cadence writers still commit via
ambient identity and would re-leak if `.git/config` regresses
(tracked by the ambient-identity-writer-audit node):

- `automation/cadence/day/01-lesson-harvest.sh:86`
- `automation/cadence/day/14-plan-ledger-sync.sh:39`
- `automation/cadence/day/17-torch-audit.sh:202`
- `automation/cadence/hour/30-kernel-ledger-sync.sh:45`
- `automation/cadence/hour/33-research-beat.sh:183`

## Alert trail

Alert `fb894f8d` (2026-09-13 04:10Z) named the Fixture identity hours
after it appeared; the loop-history guard went red same-day and the
ceremony refusal was correct behavior. The cleanup itself was not
executed for three days — the gap was execution, not detection. Filed
upstream (jcode maintainer): the deep-swarm machinery defects
encountered while auditing this (gate ownership-strip variants, driver
await-wedge) are separate records.
