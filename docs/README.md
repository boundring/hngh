# Hngh documentation

This directory is the active working surface.

## Read in this order

1. [Architecture](architecture.md) — the current kernel and planned boundary map.
2. [Run contract](core/run-contract.md) — domain values, lifecycle, and refusals.
3. [Clean Architecture charter](core/clean-architecture-charter.md) —
   dependency direction and promotion rules.
4. [Component map](core/component-map.md) — responsibilities and public APIs.
5. [Test boundary](core/test-boundary.md) — fixture and gate rules.
6. [Autonomous development control](design/autonomous-development-control.md) —
   source-grounded principle, review, and mutation-certificate policy.
7. [Presentation boundary](design/presentation-boundary.md) — factual renderer
   and reference-lexicon limits.
8. [Roadmap](project/roadmap.md) — the ordered rebuild frontier.
9. [Decisions](project/decisions.md) — decisions already made.
10. [Backlog](project/backlog.md) — work not yet admitted.
11. [Records](records/README.md) — evidence and cutover records.

## Archive boundary

The retired Hngh system is outside the repository in an operator-configured
local archive.

Read [the crystallized cutover record](records/2026-08-11-crystallized-cutover.md)
before consulting it. The archive is historical evidence only. It does not
supply a runtime, configuration, or implementation dependency.

Run `HNGH_ARCHIVE_ROOT=/absolute/path/to/archive make check-archive` to verify
the external archive when it is available.
