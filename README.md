# Hngh

Hngh is a compact local control kernel for bounded, evidenced work runs. It
starts no daemon and owns no background process.

## Status

The active baseline exposes `hngh.domain` plus `hngh.application:create-run`,
`hngh.application:arm-run`, `hngh.application:start-run`, and
`hngh.application:checkpoint`. The domain supplies pure profile, mission, role,
loadout, run, receipt, score, and afterlife values. `create-run` receives only
explicit identifier, clock, and atomic recording callbacks. `arm-run` receives
only explicit admission facts and atomic recording callbacks. `start-run`
receives only an atomic recording callback. `checkpoint` receives only
verification, manifest, and atomic recording callbacks; its evidence callbacks
receive a run-only request. They return closed application results; callback
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
python3 tests/scripts/test-verify-candidate.py
make verify-candidate CANDIDATE_MANIFEST=path/to/manifest
HNGH_ARCHIVE_ROOT=/absolute/path/to/retirement-archive make check-archive
```

`make verify-candidate` requires an explicit, sorted manifest of regular
repository-relative files. It reports whole-tree state as evidence but never
uses it to infer candidate scope. It refuses excluded `.hermes/**`, ignored,
unknown, escaping, malformed, or unsafe candidate input and performs no Git
mutation, provider call, service start, or archive read.

`check-archive` verifies the configured local retirement archive. It has no
default archive location and does not write to the archive.

## Documentation

Start at [docs/README.md](docs/README.md). It separates the active baseline
from the external retirement archive in two document hops.
