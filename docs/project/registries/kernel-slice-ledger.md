# Kernel slice ledger

One row per certificate-lane kernel mutation landed via the ceremony
(`scripts/omp-bridge --ceremony`). Columns:

```
slug | bead | paths | gate-sha | cert | sha
```

- `slug` — candidate slug as proposed
- `bead` — tracking bead id (or `-` when none)
- `paths` — ceremony manifest, space-separated
- `gate-sha` — sha256 of the green `make test` output captured for the row
- `cert` — candidate content-hash from the ceremony record
- `sha` — landed commit

## Rows

```
d5u-filesystem-open-race | hngh-d5u | src/adapter/filesystem.lisp tests/adapter/test-filesystem.lisp docs/records/2026-09-21-filesystem-toctou-fault.md CHANGELOG.md README.md | ec024aab217d3f8ea1b7da975b722084b998d2acbe9f6e5894fde9a87f5e589f | bb7f4a5e9b21fa5718c153d086b82ca75edbd671b02b7d745dd34f03360eb27d | 142a1899
```
