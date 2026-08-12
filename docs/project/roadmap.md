# Roadmap

## Current: clean-slate baseline

The retired daemon and plugin system is archived and not part of the active
product. The active kernel validates ordered, duplicate-free profile modes.

### Completed

- Sealed the retirement boundary with a read-only archive verifier.
- Retired the obsolete Mission Control desktop launcher.
- Preserved the launcher's bytes and parent configuration in a supplemental
  archive receipt.

### Next

1. Publish the Clean Architecture charter and component map.
2. Add a dependency-guard fixture and presentation-only reference-lexicon
   fixture.
3. Specify the run domain before persisting state.

No daemon, provider, watcher, scheduler, dashboard, or adapter is admitted by
this roadmap stage.
