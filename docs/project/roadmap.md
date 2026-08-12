# Roadmap

## Current: clean-slate baseline

The retired daemon and plugin system is archived and not part of the active
product. The active kernel contains pure profile and run-domain policy plus
four fake-backed application use cases.

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
- Added the read-only reader guard to the fast gate.
- Added `create-run` with capability-specific fake ports, atomic run-and-receipt
  recording, closed callback refusals, and visible domain/application failures.
- Added `arm-run` with four closed admission facts; only full confirmation can
  create an armed replacement run and atomic receipt.
- Added `start-run` so only the application boundary can make an armed run
  running and record its receipt.
- Added `checkpoint` so only passed verification and complete manifest evidence
  can advance a running run and record its receipt.
- Published source-grounded autonomous policy, closed principle and certificate
  vocabulary, and a human-approval deployment profile without adding execution.
- Added a read-only candidate evidence bundle with explicit manifest admission,
  candidate-local policy scans, fixed local evidence commands, and closed status
  output; it observes whole-tree state without inferring scope or mutating Git.

### Next

1. Add pure governance values, principle evaluation, and failure-disposition
   policy before candidate authorization or a concrete mutation adapter.
2. Issue non-mutating candidate authorization certificates from the admitted
   evidence bundle and governance policy.
3. Resume remaining application use cases only under the admitted policy
   proposal and evidence process.

No daemon, provider, watcher, scheduler, dashboard, adapter, or mutation
executor is admitted by this roadmap stage.
