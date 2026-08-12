# Roadmap

## Current: clean-slate baseline

The retired daemon and plugin system is archived and not part of the active
product. The active kernel contains pure profile and run-domain policy only.

### Completed

- Sealed the retirement boundary with a read-only archive verifier.
- Retired the obsolete Mission Control desktop launcher.
- Preserved the launcher's bytes and parent configuration in a supplemental
  archive receipt.
- Published the Clean Architecture charter, component map, test boundary, and
  presentation boundary.
- Added fixture guards for inward dependency direction and renderer-only
  reference lexicons.
- Specified and tested the pure run domain: closed lifecycle, typed refusal,
  validated mission/role/loadout values, and non-authoritative evidence values.

### Next

1. Add application use cases and inward port contracts against fakes.
2. Add restricted filesystem persistence only after the domain and port
   contracts are fixture-backed.

No daemon, provider, watcher, scheduler, dashboard, or adapter is admitted by
this roadmap stage.
