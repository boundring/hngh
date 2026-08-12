# Hngh documentation

This directory is the active working surface.

## Read in this order

1. [Architecture](architecture.md) — the current side-effect-free kernel.
2. [Roadmap](project/roadmap.md) — the ordered rebuild frontier.
3. [Decisions](project/decisions.md) — decisions already made.
4. [Backlog](project/backlog.md) — work not yet admitted.
5. [Records](records/README.md) — evidence and cutover records.

## Archive boundary

The retired Hngh system is outside the repository in an operator-configured
local archive.

Read [the crystallized cutover record](records/2026-08-11-crystallized-cutover.md)
before consulting it. The archive is historical evidence only. It does not
supply a runtime, configuration, or implementation dependency.

Run `HNGH_ARCHIVE_ROOT=/absolute/path/to/archive make check-archive` to verify
the external archive when it is available.
