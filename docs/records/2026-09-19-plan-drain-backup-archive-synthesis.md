# 2026-09-19 — plan-drain synthesis: backup/archive family

## Family scope

Backup vectors, archive hygiene, encryption/PII posture, and
completed-children archival (backup-*, archive-*, wr-* branches of
the deep plan, ~250 nodes).

## Completed children banked

- `docs/records/2026-09-17-render-blocks-strip-and-userspace-record-disposition.md`:
  dangling-object disposition (autostash `91ab48ca`, untracked-files
  `13ac26f9`) — uniqueness removed, landing verified p0-safe.
- Archive encryption/PII sweeps (archive-enc-*, archive-pii-*):
  completed sweeps live in records (e.g. scrub-consolidation,
  token-file-0600 gates, unsloth-tokenfile-600 gate); the two-home
  split of record: userspace data under `~/.hngh/`, secrets and
  kernel run stores under `~/.hngh-automation/`, nothing under
  `~/.hngh/` ever committed.
- Backup vector probes (backup-gpg-*, backup-remote-sync,
  backup-denylist-*, backup-perms/mode-bits/tmp-perms): completed
  probes live in records and patrol checks; remaining open gate
  nodes are re-verification cadence, not new work.
- Writer/reader compat and digest/newspaper/dispatch scrub seams:
  landed and fixture-backed per the scrub-consolidation record.

## Park decision

The backup/archive audit is closed as an audit: posture is verified
and the standing rules (two-home split, 0600 token files, denylist
excludes, push-after-close) are the mitigation. Remaining gate nodes
are recurring patrol cadence, not plan work — they belong to the
patrol/cadence operator role (`hngh-6qs`), not to a deep graph.

## Follow-ups (bead)

Filed as bead `hngh-backup-follow` (placeholder — see implement
step): hand residual re-verification cadence to patrol role; any new
backup-vector finding files its own small light-graph bead.
