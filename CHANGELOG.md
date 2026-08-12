# Changelog

All notable changes to Hngh are documented here.

## [Unreleased]

### Added

- Compact, side-effect-free kernel baseline with explicit profile validation.
- Read-only archive receipt verification through `make check-archive`.
- Compact active documentation and cutover record.
- Clean Architecture charter, component map, test boundary, and
  presentation/reference-lexicon boundaries.
- Fixture guards for inward dependency direction and renderer-only lexicons.
- A read-only, fixture-tested Common Lisp parenthesis guard in the fast gate.
- A pure run domain with validated mission, role, loadout, lifecycle, and
  evidence values.
- A pure application create-run slice with explicit identifier, clock, and
  atomic recording capabilities.
- A pure application arm-run slice with explicit admission facts and atomic
  recording capabilities.
- A pure application start-run slice with one atomic transition recording
  capability.

### Changed

- Application callback failures now refuse at the invocation boundary while
  domain and application errors remain visible to the test gate.
- Retired the previous daemon, plugin, watcher, dashboard, mission-control,
  launcher, and unit architecture into an external local archive.
