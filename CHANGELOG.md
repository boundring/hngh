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
- A pure run domain with validated mission, role, loadout, lifecycle, and
  evidence values.

### Changed

- Retired the previous daemon, plugin, watcher, dashboard, mission-control,
  launcher, and unit architecture into an external local archive.
