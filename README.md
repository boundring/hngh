# Hngh

Hngh is a compact local control kernel for bounded, evidenced work runs. It
starts no daemon and owns no background process.

## Status

The active baseline validates ordered profile modes: `work`, `agents`,
`machine`, and `observe`. Malformed, unknown, or duplicate modes fail closed.
Integration adapters arrive only with named ports and fixture-backed contracts.

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
