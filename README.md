# Hngh

Hngh is a compact local control kernel for bounded, evidenced work runs. It
starts no daemon and owns no background process.

## Status

The active baseline exposes `hngh.domain` plus `hngh.application:create-run`
and `hngh.application:arm-run`.
The domain supplies pure profile, mission, role, loadout, run, receipt, score,
and afterlife values. `create-run` receives only explicit identifier, clock, and
atomic recording callbacks. `arm-run` receives only explicit admission facts and
atomic recording callbacks. They return closed application results; callback
failures refuse, while domain and application faults remain visible to the test
gate. Runs begin in `created` and advance only through a closed, fail-closed
lifecycle. Receipts, scores, and lessons are evidence only; they cannot grant
authority or change run state.

`hngh:validate-profile` remains a compatibility facade over the domain policy.
Malformed, unknown, or duplicate values fail closed. Integration adapters arrive
only with named ports and fixture-backed contracts.

## Verify

```sh
make test
HNGH_ARCHIVE_ROOT=/absolute/path/to/retirement-archive make check-archive
```

`check-archive` verifies the configured local retirement archive. It has no
default archive location and does not write to the archive.

## Documentation

Start at [docs/README.md](docs/README.md). It separates the active baseline
from the external retirement archive in two document hops.
